import React, { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { io, Socket } from "socket.io-client";
import AnimatedBackground from "../components/AnimatedBackground";
import { LoginButton } from "../components/LoginButton";
import { useAuth } from "../hooks/useAuth";

interface Room {
  id: string;
  name: string;
  participants: number;
  createdAt: string;
  createdBy: string;
  isOwner: boolean;
}

interface Participant {
  id: string;
  username: string;
  socketId: string;
  stream?: MediaStream;
}

interface WebRTCConnection {
  peerConnection: RTCPeerConnection;
  socketId: string;
}

const SIGNALING_SERVER =
  import.meta.env.VITE_WEBRTC_SIGNALING_URL || "http://localhost:3000";

const ICE_SERVERS = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" },
    { urls: "stun:stun1.l.google.com:19302" },
  ],
};

export default function VideoChat() {
  const { user } = useAuth();
  const [socket, setSocket] = useState<Socket | null>(null);
  const [rooms, setRooms] = useState<Room[]>([]);
  const [currentRoomId, setCurrentRoomId] = useState("");
  const [currentRoomName, setCurrentRoomName] = useState("");
  const [isRoomOwner, setIsRoomOwner] = useState(false);
  const [newRoomName, setNewRoomName] = useState("");
  const [joined, setJoined] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showJoinModal, setShowJoinModal] = useState(false);
  const [selectedRoomId, setSelectedRoomId] = useState("");
  const [selectedRoomName, setSelectedRoomName] = useState("");
  const [participants, setParticipants] = useState<Participant[]>([]);
  const [currentUserId, setCurrentUserId] = useState<string>("");
  const [localStream, setLocalStream] = useState<MediaStream | null>(null);
  const [loading, setLoading] = useState(false);
  const [audioEnabled, setAudioEnabled] = useState(true);
  const [videoEnabled, setVideoEnabled] = useState(true);
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [remoteSpeaking, setRemoteSpeaking] = useState<Set<string>>(new Set());

  const localVideoRef = useRef<HTMLVideoElement>(null);
  const peerConnectionsRef = useRef<Map<string, WebRTCConnection>>(new Map());
  const audioContextRef = useRef<AudioContext | null>(null);
  const localAnalyserRef = useRef<AnalyserNode | null>(null);
  const remoteAnalysersRef = useRef<Map<string, AnalyserNode>>(new Map());

  // Update local video when stream changes or when we join the room
  useEffect(() => {
    if (!localStream) return;

    // Use a small delay to ensure ref is attached
    const timer = setTimeout(() => {
      if (localVideoRef.current && localStream) {
        console.log("Setting local video srcObject");
        console.log("Stream active:", localStream.active);
        console.log(
          "Stream tracks:",
          localStream.getTracks().map((t) => ({
            kind: t.kind,
            enabled: t.enabled,
            readyState: t.readyState,
            label: t.label,
          }))
        );

        // Make absolutely sure video track is enabled
        const videoTrack = localStream.getVideoTracks()[0];
        if (videoTrack) {
          console.log("Video track before assignment:", {
            enabled: videoTrack.enabled,
            muted: videoTrack.muted,
            readyState: videoTrack.readyState,
          });
          videoTrack.enabled = true;
        }

        localVideoRef.current.srcObject = localStream;

        console.log("Video element after srcObject set:", {
          srcObject: localVideoRef.current.srcObject,
          videoWidth: localVideoRef.current.videoWidth,
          videoHeight: localVideoRef.current.videoHeight,
          readyState: localVideoRef.current.readyState,
        });
      } else {
        console.error("❌ Local video ref is null!");
      }
    }, 100);

    return () => {
      clearTimeout(timer);
      if (localAnalyserRef.current) {
        localAnalyserRef.current = null;
      }
    };
  }, [localStream]);

  // Setup audio analyzer separately after a delay
  useEffect(() => {
    if (localStream && joined) {
      const timer = setTimeout(() => {
        setupLocalAudioAnalyzer(localStream);
      }, 1000);

      return () => clearTimeout(timer);
    }
  }, [localStream, joined]);

  // Fetch rooms list
  const setupLocalAudioAnalyzer = (stream: MediaStream) => {
    try {
      if (!audioContextRef.current) {
        audioContextRef.current = new AudioContext();
      }

      const audioContext = audioContextRef.current;
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 256;
      analyser.smoothingTimeConstant = 0.8;

      // Create a new stream with cloned audio track to avoid interfering with video
      const audioTrack = stream.getAudioTracks()[0];
      if (audioTrack) {
        const audioStream = new MediaStream([audioTrack]);
        const source = audioContext.createMediaStreamSource(audioStream);
        source.connect(analyser);
        // Don't connect to destination to avoid audio feedback
      }

      localAnalyserRef.current = analyser;

      // Start monitoring audio levels
      monitorAudioLevel(analyser, (speaking) => setIsSpeaking(speaking));
    } catch (error) {
      console.error("Error setting up local audio analyzer:", error);
    }
  };

  const setupRemoteAudioAnalyzer = (
    stream: MediaStream,
    participantId: string
  ) => {
    try {
      if (!audioContextRef.current) {
        audioContextRef.current = new AudioContext();
      }

      const audioContext = audioContextRef.current;
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 256;
      analyser.smoothingTimeConstant = 0.8;

      // Create a new stream with audio track to avoid interfering with video
      const audioTrack = stream.getAudioTracks()[0];
      if (audioTrack) {
        const audioStream = new MediaStream([audioTrack]);
        const source = audioContext.createMediaStreamSource(audioStream);
        source.connect(analyser);
        // Don't connect to destination
      }

      remoteAnalysersRef.current.set(participantId, analyser);

      // Start monitoring audio levels
      monitorAudioLevel(analyser, (speaking) => {
        setRemoteSpeaking((prev) => {
          const newSet = new Set(prev);
          if (speaking) {
            newSet.add(participantId);
          } else {
            newSet.delete(participantId);
          }
          return newSet;
        });
      });
    } catch (error) {
      console.error("Error setting up remote audio analyzer:", error);
    }
  };

  const monitorAudioLevel = (
    analyser: AnalyserNode,
    callback: (speaking: boolean) => void
  ) => {
    const dataArray = new Uint8Array(analyser.frequencyBinCount);
    const SPEAKING_THRESHOLD = 30; // Adjust this value to change sensitivity

    const checkAudioLevel = () => {
      analyser.getByteFrequencyData(dataArray);
      const average = dataArray.reduce((a, b) => a + b) / dataArray.length;
      callback(average > SPEAKING_THRESHOLD);
    };

    const interval = setInterval(checkAudioLevel, 100);

    // Store interval for cleanup (you might want to manage this better)
    return () => clearInterval(interval);
  };

  const fetchRooms = async () => {
    if (!user?.access_token) return;

    try {
      const response = await fetch(`${SIGNALING_SERVER}/api/rooms`, {
        headers: {
          Authorization: `Bearer ${user.access_token}`,
        },
      });
      if (response.ok) {
        const data = await response.json();
        setRooms(data.rooms || []);
      }
    } catch (error) {
      console.error("Error fetching rooms:", error);
    }
  };

  // Initialize socket connection
  useEffect(() => {
    if (!user?.access_token) return;

    const newSocket = io(SIGNALING_SERVER, {
      transports: ["websocket", "polling"],
      auth: {
        token: user.access_token,
      },
    });

    newSocket.on("connect", () => {
      console.log("Connected to signaling server");
    });

    newSocket.on("disconnect", () => {
      console.log("Disconnected from signaling server");
    });

    newSocket.on("connect_error", (error) => {
      console.error("Connection error:", error.message);
    });

    setSocket(newSocket);

    // Fetch rooms initially and every 5 seconds
    fetchRooms();
    const interval = setInterval(fetchRooms, 5000);

    return () => {
      newSocket.close();
      clearInterval(interval);
    };
  }, [user]);

  // Setup socket event listeners
  useEffect(() => {
    if (!socket) return;

    socket.on(
      "joined-room",
      async ({ userId, roomId, participants: existingParticipants }) => {
        console.log(
          "✅ Joined room:",
          roomId,
          "My userId:",
          userId,
          "My socketId:",
          socket.id,
          "Existing participants:",
          existingParticipants
        );
        setJoined(true);
        setCurrentUserId(userId);

        // Filter out current socket but keep other instances of same user
        const otherParticipants = existingParticipants.filter(
          (p: Participant) => {
            const keep = p.socketId !== socket.id;
            console.log(
              `Participant ${p.username} (${p.socketId}): ${
                keep ? "KEEP" : "FILTER OUT"
              }`
            );
            return keep;
          }
        );
        console.log("Other participants after filter:", otherParticipants);
        setParticipants(otherParticipants);

        // Note: Don't create peer connections here - wait for localStream to be available
        // The useEffect below will handle it
      }
    );

    socket.on("user-joined", async ({ userId, username, socketId }) => {
      console.log("👤 User joined:", username, socketId, "userId:", userId);

      // Don't add ourselves
      if (socketId === socket.id) {
        console.log("Ignoring our own join event");
        return;
      }

      console.log("Adding participant to list");
      setParticipants((prev) => {
        const updated = [...prev, { id: userId, username, socketId }];
        console.log("Participants after adding:", updated);
        return updated;
      });

      // Only initiate if our socket ID is greater (to prevent both sides initiating)
      if (localStream) {
        if (socket.id! > socketId) {
          console.log(
            "📞 New user joined, initiating connection to:",
            username,
            socketId
          );
          await createPeerConnection(socketId, true);
        } else {
          console.log(
            "⏳ New user joined, waiting for them to initiate:",
            username,
            socketId
          );
        }
      } else {
        console.warn("⚠️ Cannot initiate connection, no local stream yet");
      }
    });

    socket.on("user-left", ({ username, socketId }) => {
      console.log("User left:", username, socketId);

      // Remove participant by socketId, not userId (to handle multi-tab)
      setParticipants((prev) => prev.filter((p) => p.socketId !== socketId));

      // Close and remove the specific peer connection
      const connection = peerConnectionsRef.current.get(socketId);
      if (connection) {
        console.log("Closing peer connection for:", socketId);
        connection.peerConnection.close();
        peerConnectionsRef.current.delete(socketId);
      }
    });

    socket.on("webrtc-offer", async ({ from, offer }) => {
      console.log("Received offer from:", from);
      await handleOffer(from, offer);
    });

    socket.on("webrtc-answer", async ({ from, answer }) => {
      console.log("Received answer from:", from);
      await handleAnswer(from, answer);
    });

    socket.on("ice-candidate", async ({ from, candidate }) => {
      console.log("Received ICE candidate from:", from);
      await handleIceCandidate(from, candidate);
    });

    socket.on("error", ({ message }) => {
      console.error("Socket error:", message);
      alert(`Error: ${message}`);
    });

    return () => {
      socket.off("joined-room");
      socket.off("user-joined");
      socket.off("user-left");
      socket.off("webrtc-offer");
      socket.off("webrtc-answer");
      socket.off("ice-candidate");
      socket.off("error");
    };
  }, [socket, localStream]);

  // When we first join with a local stream and there are existing participants,
  // we need to initiate connections to them
  useEffect(() => {
    if (joined && localStream && participants.length > 0 && socket) {
      console.log("✅ Ready for WebRTC. Participants:", participants.length);
      console.log("   My socket ID:", socket.id);
      console.log("   Initiating connections to existing participants...");

      // Create peer connections to all existing participants
      // Only initiate if our socket ID is greater (to prevent both sides initiating)
      participants.forEach(async (participant) => {
        if (!peerConnectionsRef.current.has(participant.socketId)) {
          if (socket.id! > participant.socketId) {
            console.log(
              "🔗 Creating connection to existing participant:",
              participant.username,
              participant.socketId
            );
            await createPeerConnection(participant.socketId, true);
          } else {
            console.log(
              "⏳ Waiting for",
              participant.username,
              participant.socketId,
              "to initiate (their turn)"
            );
          }
        }
      });
    }
  }, [joined, localStream, participants.length, socket]);

  const createPeerConnection = async (socketId: string, initiator: boolean) => {
    console.log(
      "🔗 Creating peer connection for:",
      socketId,
      "Initiator:",
      initiator
    );

    if (peerConnectionsRef.current.has(socketId)) {
      console.log("⚠️ Peer connection already exists for:", socketId);
      return;
    }

    const peerConnection = new RTCPeerConnection(ICE_SERVERS);
    console.log("✅ RTCPeerConnection created");

    // Add local stream tracks
    if (localStream) {
      console.log("➕ Adding local tracks to peer connection");
      localStream.getTracks().forEach((track) => {
        console.log("  Adding track:", track.kind, "enabled:", track.enabled);
        peerConnection.addTrack(track, localStream);
      });
    } else {
      console.warn("⚠️ No local stream available to add tracks");
    }

    // Handle incoming streams
    peerConnection.ontrack = (event) => {
      console.log("📥 Received remote track from:", socketId);
      console.log("  Track kind:", event.track.kind);
      console.log("  Track enabled:", event.track.enabled);
      console.log("  Track readyState:", event.track.readyState);
      console.log("  Streams:", event.streams);
      console.log("  Stream[0] id:", event.streams[0]?.id);
      console.log("  Stream[0] active:", event.streams[0]?.active);
      console.log("  Stream[0] tracks:", event.streams[0]?.getTracks());

      const remoteStream = event.streams[0];
      if (remoteStream) {
        console.log("✅ Setting remote stream for participant:", socketId);
        setParticipants((prev) => {
          const updated = prev.map((p) => {
            if (p.socketId === socketId) {
              console.log("  Updating participant:", p.username, "with stream");
              // Setup audio analyzer for remote stream
              setupRemoteAudioAnalyzer(remoteStream, p.id);
              return { ...p, stream: remoteStream };
            }
            return p;
          });
          console.log("  Participants after update:", updated);
          return updated;
        });
      } else {
        console.error("❌ No remote stream in event");
      }
    };

    // Handle ICE candidates
    peerConnection.onicecandidate = (event) => {
      if (event.candidate && socket) {
        console.log("🧊 Sending ICE candidate to:", socketId);
        socket.emit("ice-candidate", {
          to: socketId,
          candidate: event.candidate,
        });
      } else if (!event.candidate) {
        console.log("🧊 ICE gathering complete for:", socketId);
      }
    };

    // Handle connection state
    peerConnection.onconnectionstatechange = () => {
      console.log(
        "🔌 Connection state for",
        socketId,
        ":",
        peerConnection.connectionState
      );
      if (peerConnection.connectionState === "failed") {
        console.error("❌ Connection failed for:", socketId);
      }
    };

    // Handle ICE connection state
    peerConnection.oniceconnectionstatechange = () => {
      console.log(
        "🧊 ICE connection state for",
        socketId,
        ":",
        peerConnection.iceConnectionState
      );
    };

    peerConnectionsRef.current.set(socketId, { peerConnection, socketId });
    console.log("💾 Stored peer connection for:", socketId);

    // If initiator, create and send offer
    if (initiator && socket) {
      console.log("📤 Creating and sending offer to:", socketId);
      const offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      console.log("📤 Offer created, local description set");

      socket.emit("webrtc-offer", {
        to: socketId,
        offer: offer,
      });
      console.log("✅ Offer sent to:", socketId);
    }
  };

  const handleOffer = async (
    from: string,
    offer: RTCSessionDescriptionInit
  ) => {
    console.log("📨 Received offer from:", from);

    if (!localStream) {
      console.error("❌ Cannot handle offer - no local stream yet!");
      return;
    }

    let connection = peerConnectionsRef.current.get(from);

    if (!connection) {
      console.log("  No existing connection, creating new one");
      await createPeerConnection(from, false);
      connection = peerConnectionsRef.current.get(from);
    }

    if (!connection) {
      console.error("❌ Failed to create peer connection");
      return;
    }

    console.log("  Setting remote description");
    await connection.peerConnection.setRemoteDescription(
      new RTCSessionDescription(offer)
    );
    console.log("  Creating answer");
    const answer = await connection.peerConnection.createAnswer();
    console.log("  Setting local description");
    await connection.peerConnection.setLocalDescription(answer);

    if (socket) {
      console.log("📤 Sending answer to:", from);
      socket.emit("webrtc-answer", {
        to: from,
        answer: answer,
      });
      console.log("✅ Answer sent");
    }
  };

  const handleAnswer = async (
    from: string,
    answer: RTCSessionDescriptionInit
  ) => {
    console.log("📨 Received answer from:", from);
    const connection = peerConnectionsRef.current.get(from);
    if (!connection) {
      console.error("❌ No peer connection found for:", from);
      return;
    }

    const signalingState = connection.peerConnection.signalingState;
    console.log("  Current signaling state:", signalingState);

    // If already stable, the connection is established - ignore duplicate answer
    if (signalingState === "stable") {
      console.log("  Connection already stable, ignoring duplicate answer");
      return;
    }

    if (signalingState !== "have-local-offer") {
      console.error(
        "❌ Cannot set remote answer, unexpected state:",
        signalingState
      );
      return;
    }

    console.log("  Setting remote description");
    await connection.peerConnection.setRemoteDescription(
      new RTCSessionDescription(answer)
    );
    console.log("✅ Remote description set");
  };

  const handleIceCandidate = async (
    from: string,
    candidate: RTCIceCandidateInit
  ) => {
    console.log("🧊 Received ICE candidate from:", from);
    const connection = peerConnectionsRef.current.get(from);
    if (!connection) {
      console.error("❌ No peer connection found for:", from);
      return;
    }

    try {
      await connection.peerConnection.addIceCandidate(
        new RTCIceCandidate(candidate)
      );
      console.log("✅ ICE candidate added");
    } catch (error) {
      console.error("❌ Error adding ICE candidate:", error);
    }
  };

  const startLocalStream = async () => {
    try {
      console.log("Requesting media devices...");
      const stream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true,
      });

      console.log("Got local stream:", stream);
      console.log("Video tracks:", stream.getVideoTracks());
      console.log(
        "Video track settings:",
        stream.getVideoTracks()[0]?.getSettings()
      );
      console.log("Audio tracks:", stream.getAudioTracks());

      // Just set the stream state, useEffect will handle the rest
      setLocalStream(stream);

      return stream;
    } catch (error) {
      console.error("Error accessing media devices:", error);
      alert("Could not access camera/microphone. Please check permissions.");
      throw error;
    }
  };

  const createRoom = async () => {
    if (!newRoomName) {
      alert("Please enter a room name");
      return;
    }

    if (!user?.access_token) {
      alert("Authentication required");
      return;
    }

    setLoading(true);

    try {
      const response = await fetch(`${SIGNALING_SERVER}/api/rooms`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${user.access_token}`,
        },
        body: JSON.stringify({ name: newRoomName }),
      });

      if (response.ok) {
        const data = await response.json();
        setNewRoomName("");
        setShowCreateModal(false);
        fetchRooms();
        // Show join modal for the newly created room
        setSelectedRoomId(data.id);
        setSelectedRoomName(data.name);
        setShowJoinModal(true);
      } else {
        alert("Failed to create room");
      }
    } catch (error) {
      console.error("Error creating room:", error);
      alert("Error creating room");
    } finally {
      setLoading(false);
    }
  };

  const deleteRoom = async (roomId: string, roomName: string) => {
    if (!user?.access_token) {
      alert("Authentication required");
      return;
    }

    if (
      !confirm(
        `Are you sure you want to delete the room "${roomName}"? All participants will be removed.`
      )
    ) {
      return;
    }

    try {
      const response = await fetch(`${SIGNALING_SERVER}/api/rooms/${roomId}`, {
        method: "DELETE",
        headers: {
          Authorization: `Bearer ${user.access_token}`,
        },
      });

      if (response.ok) {
        alert("Room deleted successfully");
        fetchRooms();
        // If we're in the room being deleted, leave it
        if (currentRoomId === roomId) {
          leaveRoom();
        }
      } else {
        const error = await response.json();
        alert(error.error || "Failed to delete room");
      }
    } catch (error) {
      console.error("Error deleting room:", error);
      alert("Error deleting room");
    }
  };

  const handleJoinClick = (roomId: string, roomName: string) => {
    setSelectedRoomId(roomId);
    setSelectedRoomName(roomName);
    setShowJoinModal(true);
  };

  const joinRoom = async () => {
    if (!socket || !selectedRoomId) {
      return;
    }

    setLoading(true);

    try {
      // Fetch room details to check ownership
      const response = await fetch(
        `${SIGNALING_SERVER}/api/rooms/${selectedRoomId}`,
        {
          headers: {
            Authorization: `Bearer ${user?.access_token}`,
          },
        }
      );

      if (response.ok) {
        const roomData = await response.json();
        setIsRoomOwner(roomData.isOwner || false);
      }

      await startLocalStream();

      socket.emit("join-room", {
        roomId: selectedRoomId,
      });

      setCurrentRoomId(selectedRoomId);
      setCurrentRoomName(selectedRoomName);
      setShowJoinModal(false);
    } catch (error) {
      console.error("Failed to start stream:", error);
      alert("Failed to access camera/microphone");
    } finally {
      setLoading(false);
    }
  };

  const leaveRoom = () => {
    if (socket) {
      socket.emit("leave-room");
    }

    // Stop local stream
    if (localStream) {
      localStream.getTracks().forEach((track) => track.stop());
      setLocalStream(null);
    }

    // Close all peer connections
    peerConnectionsRef.current.forEach((conn) => {
      conn.peerConnection.close();
    });
    peerConnectionsRef.current.clear();

    // Clear audio analyzers
    localAnalyserRef.current = null;
    remoteAnalysersRef.current.clear();
    setIsSpeaking(false);
    setRemoteSpeaking(new Set());

    // Close audio context
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }

    setJoined(false);
    setParticipants([]);
    setCurrentUserId("");
    setAudioEnabled(true);
    setVideoEnabled(true);
    setIsRoomOwner(false);
  };

  const toggleAudio = () => {
    if (localStream) {
      const audioTrack = localStream.getAudioTracks()[0];
      if (audioTrack) {
        audioTrack.enabled = !audioTrack.enabled;
        setAudioEnabled(audioTrack.enabled);
        console.log("🔊 Audio", audioTrack.enabled ? "enabled" : "muted");
      }
    }
  };

  const toggleVideo = () => {
    if (localStream) {
      const videoTrack = localStream.getVideoTracks()[0];
      if (videoTrack) {
        videoTrack.enabled = !videoTrack.enabled;
        setVideoEnabled(videoTrack.enabled);
        console.log("📹 Video", videoTrack.enabled ? "enabled" : "disabled");
      }
    }
  };

  return (
    <div className="relative min-h-screen overflow-hidden">
      <AnimatedBackground />
      <div className="relative z-10 px-6 pb-20 pt-10">
        <header className="mx-auto flex w-full max-w-6xl flex-col gap-4">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-baseline sm:justify-between">
            <div>
              <p className="text-xs uppercase tracking-[0.35em] text-slate-500">
                WebRTC Video
              </p>
              <h1 className="text-3xl font-semibold text-white">
                Video Chat Rooms
              </h1>
            </div>
          </div>

          {/* Connection Status */}
          <div className="rounded-2xl border border-white/10 bg-black/40 p-4 backdrop-blur">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div>
                  <p className="text-xs uppercase tracking-[0.3em] text-slate-500">
                    {joined ? `In Room: ${currentRoomName}` : "Browsing Rooms"}
                  </p>
                  {joined && user && (
                    <p className="mt-1 text-sm text-white">
                      <span className="font-semibold">
                        {user.profile?.name ||
                          user.profile?.preferred_username ||
                          user.profile?.email ||
                          "User"}
                      </span>
                    </p>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-3">
                <Link
                  to="/"
                  className="text-sm text-slate-400 hover:text-white transition-colors"
                >
                  ← Home
                </Link>
                <LoginButton />
              </div>
            </div>
          </div>
        </header>

        <main className="mx-auto mt-12 w-full max-w-6xl">
          {!joined ? (
            <div className="space-y-6">
              {/* Create Room Button */}
              <div className="flex justify-between items-center">
                <h2 className="text-xl font-semibold text-white">
                  Available Rooms
                </h2>
                <button
                  onClick={() => setShowCreateModal(true)}
                  className="rounded-2xl bg-emerald-500/20 px-6 py-3 text-sm font-semibold text-emerald-300 transition hover:bg-emerald-500/30"
                >
                  + Create Room
                </button>
              </div>

              {/* Rooms List */}
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
                {rooms.length === 0 ? (
                  <div className="col-span-full rounded-3xl border border-white/10 bg-black/40 p-12 text-center shadow-neon backdrop-blur">
                    <p className="text-slate-400">
                      No rooms available. Create one to get started!
                    </p>
                  </div>
                ) : (
                  rooms.map((room) => (
                    <div
                      key={room.id}
                      className="rounded-3xl border border-white/10 bg-black/40 p-6 shadow-neon backdrop-blur hover:border-cyan-400/50 transition-colors"
                    >
                      <div className="flex flex-col gap-4">
                        <div>
                          <h3 className="text-lg font-semibold text-white">
                            {room.name}
                          </h3>
                          <div className="mt-2 flex items-center gap-2 text-sm text-slate-400">
                            <span className="flex items-center gap-1">
                              <span className="h-2 w-2 rounded-full bg-emerald-400" />
                              {room.participants} participant
                              {room.participants !== 1 ? "s" : ""}
                            </span>
                          </div>
                          <p className="mt-2 text-xs text-slate-500">
                            Created{" "}
                            {new Date(room.createdAt).toLocaleDateString()}
                            {room.isOwner && (
                              <span className="ml-2 text-cyan-400">
                                (Owner)
                              </span>
                            )}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleJoinClick(room.id, room.name)}
                            className="flex-1 rounded-2xl bg-cyan-500/20 px-4 py-2 text-sm font-semibold text-cyan-300 transition hover:bg-cyan-500/30"
                          >
                            Join Room
                          </button>
                          {room.isOwner && (
                            <button
                              onClick={() => deleteRoom(room.id, room.name)}
                              className="rounded-2xl bg-red-500/20 px-4 py-2 text-sm font-semibold text-red-300 transition hover:bg-red-500/30"
                              title="Delete room"
                            >
                              🗑️
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              <div className="flex justify-between items-center">
                <div className="flex items-center gap-2">
                  <div className="h-2 w-2 rounded-full bg-emerald-400" />
                  <span className="text-sm text-slate-300">
                    {participants.length + 1} participant
                    {participants.length !== 0 ? "s" : ""}
                  </span>
                </div>
                <div className="flex gap-2">
                  {isRoomOwner && (
                    <button
                      onClick={() => deleteRoom(currentRoomId, currentRoomName)}
                      className="rounded-2xl bg-red-500/20 px-6 py-3 text-sm font-semibold text-red-300 transition hover:bg-red-500/30"
                    >
                      Delete Room
                    </button>
                  )}
                  <button
                    onClick={leaveRoom}
                    className="rounded-2xl bg-slate-500/20 px-6 py-3 text-sm font-semibold text-slate-300 transition hover:bg-slate-500/30"
                  >
                    Leave Room
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
                {/* Local video */}
                <div
                  className={`rounded-3xl border overflow-hidden shadow-neon backdrop-blur relative transition-all duration-200 ${
                    isSpeaking && audioEnabled
                      ? "border-emerald-400 shadow-[0_0_20px_rgba(52,211,153,0.6)] scale-[1.02]"
                      : "border-cyan-400/50 bg-black/40"
                  }`}
                >
                  {!videoEnabled && (
                    <div className="absolute inset-0 flex items-center justify-center bg-black/80 z-10">
                      <div className="text-center">
                        <span className="text-6xl">📹</span>
                        <p className="mt-2 text-sm text-slate-300">Video Off</p>
                      </div>
                    </div>
                  )}
                  <video
                    ref={localVideoRef}
                    autoPlay
                    muted
                    playsInline
                    onLoadedMetadata={(e) => {
                      console.log("📹 Local video metadata loaded");
                      const video = e.currentTarget;
                      console.log("Video dimensions:", {
                        videoWidth: video.videoWidth,
                        videoHeight: video.videoHeight,
                      });
                      console.log("Video srcObject:", video.srcObject);
                      console.log(
                        "Stream active:",
                        (video.srcObject as MediaStream)?.active
                      );
                      const stream = video.srcObject as MediaStream;
                      if (stream) {
                        console.log(
                          "Video tracks in stream:",
                          stream.getVideoTracks().map((t) => ({
                            id: t.id,
                            label: t.label,
                            enabled: t.enabled,
                            muted: t.muted,
                            readyState: t.readyState,
                          }))
                        );
                      }
                    }}
                    onCanPlay={() => {
                      console.log("📹 Local video can play");
                    }}
                    onPlay={() => console.log("📹 Local video started playing")}
                    onPause={() => console.log("⚠️ Local video paused")}
                    onError={(e) => console.error("📹 Local video error:", e)}
                    style={{ transform: "scaleX(-1)" }}
                    className="w-full h-64 object-cover bg-black"
                  />
                  <div className="p-4 bg-gradient-to-b from-cyan-500/10 to-transparent">
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <p className="text-sm font-semibold text-white">
                          You (
                          {user?.profile?.name ||
                            user?.profile?.preferred_username ||
                            user?.profile?.email ||
                            "User"}
                          )
                        </p>
                        <p className="text-xs text-slate-400 mt-1">
                          Local stream
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <button
                        onClick={toggleAudio}
                        className={`flex-1 flex items-center justify-center gap-2 rounded-xl px-3 py-2 text-xs font-semibold transition ${
                          audioEnabled
                            ? "bg-slate-500/20 text-slate-300 hover:bg-slate-500/30"
                            : "bg-red-500/20 text-red-300 hover:bg-red-500/30"
                        }`}
                      >
                        <span className="text-base">
                          {audioEnabled ? "🔊" : "🔇"}
                        </span>
                        <span>{audioEnabled ? "Mute" : "Unmute"}</span>
                      </button>
                      <button
                        onClick={toggleVideo}
                        className={`flex-1 flex items-center justify-center gap-2 rounded-xl px-3 py-2 text-xs font-semibold transition ${
                          videoEnabled
                            ? "bg-slate-500/20 text-slate-300 hover:bg-slate-500/30"
                            : "bg-red-500/20 text-red-300 hover:bg-red-500/30"
                        }`}
                      >
                        <span className="text-base">
                          {videoEnabled ? "📹" : "📹"}
                        </span>
                        <span>{videoEnabled ? "Stop" : "Start"}</span>
                      </button>
                    </div>
                  </div>
                </div>

                {/* Remote videos */}
                {participants.map((participant) => (
                  <RemoteVideo
                    key={participant.socketId}
                    participant={participant}
                    isSpeaking={remoteSpeaking.has(participant.id)}
                    isCurrentUser={participant.id === currentUserId}
                  />
                ))}
              </div>
            </div>
          )}
        </main>
      </div>

      {/* Create Room Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
          <div className="mx-4 w-full max-w-md rounded-3xl border border-white/10 bg-black/90 p-8 shadow-neon backdrop-blur">
            <h2 className="text-2xl font-semibold text-white mb-6">
              Create New Room
            </h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  Room Name
                </label>
                <input
                  type="text"
                  value={newRoomName}
                  onChange={(e) => setNewRoomName(e.target.value)}
                  placeholder="Enter room name"
                  className="w-full rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-white placeholder-slate-500 outline-none transition focus:border-cyan-400/70 focus:ring-2 focus:ring-cyan-400/30"
                />
              </div>
              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => {
                    setShowCreateModal(false);
                    setNewRoomName("");
                  }}
                  className="flex-1 rounded-2xl bg-slate-500/20 px-6 py-3 text-sm font-semibold text-slate-300 transition hover:bg-slate-500/30"
                >
                  Cancel
                </button>
                <button
                  onClick={createRoom}
                  disabled={loading}
                  className="flex-1 rounded-2xl bg-emerald-500/20 px-6 py-3 text-sm font-semibold text-emerald-300 transition hover:bg-emerald-500/30 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? "Creating..." : "Create"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Join Room Modal */}
      {showJoinModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
          <div className="mx-4 w-full max-w-md rounded-3xl border border-white/10 bg-black/90 p-8 shadow-neon backdrop-blur">
            <h2 className="text-2xl font-semibold text-white mb-2">
              Join Room
            </h2>
            <p className="text-slate-400 mb-4">{selectedRoomName}</p>
            <p className="text-sm text-slate-500 mb-6">
              Joining as{" "}
              <span className="text-white font-semibold">
                {user?.profile?.name ||
                  user?.profile?.preferred_username ||
                  user?.profile?.email ||
                  "User"}
              </span>
            </p>
            <div className="space-y-4">
              <div className="flex gap-3 pt-4">
                <button
                  onClick={() => {
                    setShowJoinModal(false);
                  }}
                  className="flex-1 rounded-2xl bg-slate-500/20 px-6 py-3 text-sm font-semibold text-slate-300 transition hover:bg-slate-500/30"
                >
                  Cancel
                </button>
                <button
                  onClick={joinRoom}
                  disabled={loading}
                  className="flex-1 rounded-2xl bg-cyan-500/20 px-6 py-3 text-sm font-semibold text-cyan-300 transition hover:bg-cyan-500/30 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {loading ? "Joining..." : "Join"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function RemoteVideo({
  participant,
  isSpeaking,
  isCurrentUser,
}: {
  participant: Participant;
  isSpeaking: boolean;
  isCurrentUser: boolean;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    console.log("\ud83d\udc65 RemoteVideo effect for:", participant.username);
    console.log("  Has stream:", !!participant.stream);
    console.log("  Stream id:", participant.stream?.id);
    console.log("  Stream active:", participant.stream?.active);
    console.log("  Video ref:", !!videoRef.current);

    if (videoRef.current && participant.stream) {
      console.log(
        "📺 Setting srcObject for remote video:",
        participant.username
      );
      console.log(
        "  Stream tracks:",
        participant.stream.getTracks().map((t) => ({
          kind: t.kind,
          enabled: t.enabled,
          readyState: t.readyState,
        }))
      );

      videoRef.current.srcObject = participant.stream;

      // Ensure remote video plays
      const playPromise = videoRef.current.play();
      if (playPromise !== undefined) {
        playPromise
          .then(() => {
            console.log(
              "\u2705 Remote video playing for:",
              participant.username
            );
          })
          .catch((err) => {
            console.error(
              "\u274c Remote video play error for",
              participant.username,
              ":",
              err
            );
          });
      }
    } else {
      console.log("\u26a0\ufe0f Cannot attach remote stream:", {
        hasRef: !!videoRef.current,
        hasStream: !!participant.stream,
        username: participant.username,
      });
    }
  }, [participant.stream, participant.username]);

  return (
    <div
      className={`rounded-3xl border overflow-hidden shadow-neon backdrop-blur transition-all duration-200 ${
        isSpeaking
          ? "border-emerald-400 shadow-[0_0_20px_rgba(52,211,153,0.6)] scale-[1.02]"
          : "border-blue-400/50 bg-black/40"
      }`}
    >
      <video
        ref={videoRef}
        autoPlay
        playsInline
        onLoadedMetadata={(e) => {
          console.log(
            "\ud83d\udcf9 Remote video metadata loaded for:",
            participant.username
          );
          console.log("Video dimensions:", {
            videoWidth: e.currentTarget.videoWidth,
            videoHeight: e.currentTarget.videoHeight,
          });
        }}
        onCanPlay={() =>
          console.log(
            "\ud83d\udcf9 Remote video can play for:",
            participant.username
          )
        }
        onPlay={() =>
          console.log(
            "\ud83d\udcf9 Remote video started playing for:",
            participant.username
          )
        }
        onError={(e) =>
          console.error(
            "\ud83d\udcf9 Remote video error for",
            participant.username,
            ":",
            e
          )
        }
        className="w-full h-64 object-cover bg-black"
      />
      <div className="p-4 bg-gradient-to-b from-blue-500/10 to-transparent">
        <p className="text-sm font-semibold text-white">
          {participant.username}
          {isCurrentUser && (
            <span className="ml-2 text-xs text-cyan-400 font-normal">
              (You in another tab)
            </span>
          )}
        </p>
        <p className="text-xs text-slate-400 mt-1">Remote stream</p>
      </div>
    </div>
  );
}
