export default function AnimatedBackground() {
  return (
    <div className="fixed inset-0 -z-10 overflow-hidden bg-[#020617]">
      <div className="absolute inset-0 ui-grid-lines opacity-40" />

      <div className="absolute inset-0 ui-aurora ui-shimmer blur-3xl" />

      <div className="absolute -top-32 left-1/2 h-96 w-96 -translate-x-1/2 rounded-full bg-cyan-500/40 blur-[140px]" />
      <div className="absolute bottom-[-120px] left-[12%] h-72 w-72 rounded-full bg-purple-500/30 blur-[120px] pulse-slow" />
      <div className="absolute bottom-[10%] right-[8%] h-[420px] w-[420px] rounded-full bg-pink-500/25 blur-[160px]" />

      <div className="absolute inset-0 flex items-center justify-center">
        <div className="h-[540px] w-[540px] rounded-full border border-white/5 ring-glow opacity-40" />
      </div>

      <div className="absolute inset-0">
        <div className="absolute left-[15%] top-[25%] h-32 w-32 rounded-full border border-cyan-400/30" />
        <div className="absolute right-[15%] top-[40%] h-24 w-24 rounded-2xl border border-fuchsia-400/30 rotate-12" />
        <div className="absolute left-[35%] bottom-[15%] h-20 w-20 rounded-full border border-sky-300/30" />
      </div>
    </div>
  );
}
