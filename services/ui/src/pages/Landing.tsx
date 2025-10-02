import { Link } from "react-router-dom";
import AnimatedBackground from "../components/AnimatedBackground";

export default function Landing() {
  return (
    <>
      <AnimatedBackground />
      <div className="relative flex flex-col items-center justify-center min-h-screen px-4">
        <h1 className="text-6xl font-bold text-white mb-4">Example UI</h1>
        <p className="text-xl text-gray-300 mb-8">
          Welcome to your application 123
        </p>
        <Link
          to="/app"
          className="px-8 py-3 bg-none hover:bg-blue-500 hover:bg-opacity-30 text-white font-semibold rounded-lg transition-colors"
        >
          Get Started
        </Link>
      </div>
    </>
  );
}
