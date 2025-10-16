import { Link } from "react-router-dom";
import AnimatedBackground from "../components/AnimatedBackground";
import { LoginButton } from "../components/LoginButton";
import { useAuth } from "../hooks/useAuth";

export default function Landing() {
  const { user } = useAuth();

  return (
    <>
      <AnimatedBackground />
      <div className="relative min-h-screen overflow-hidden">
        <header className="relative z-10 mx-auto flex w-full max-w-5xl items-center justify-between px-6 pt-8">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-white/10 bg-white/5 backdrop-blur">
              <span className="text-base font-semibold text-cyan-300">🚀</span>
            </div>
            <div>
              <p className="text-sm font-medium text-slate-200">
                Crew Dune Launchpad
              </p>
              <p className="text-xs text-slate-500">
                AI Project Starter Repository
              </p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            {user && (
              <div className="text-sm text-white">
                Welcome, {user.profile.name || user.profile.email}
              </div>
            )}
            <a
              href="https://github.com/bensincs/azure-project-bootstrap"
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-xs font-medium text-slate-200 transition hover:border-cyan-400/60 hover:text-white"
            >
              <span>View Repository</span>
              <span aria-hidden>↗</span>
            </a>
            <LoginButton />
          </div>
        </header>

        <main className="relative z-10 mx-auto flex w-full max-w-5xl flex-1 flex-col gap-12 px-6 pb-20 pt-24">
          <section className="max-w-3xl space-y-6">
            <h1 className="text-4xl font-semibold leading-tight text-white sm:text-5xl">
              Launchpad repo for new AI projects.
            </h1>
            <p className="text-lg text-slate-300">
              Opinionated templates wired for Azure: UI, APIs, realtime
              messaging, plus product IaC alongside separate bootstrap Terraform
              to wire GitHub identities, secrets, and subscriptions.
            </p>
            {user ? (
              <div className="flex flex-col gap-4 sm:flex-row sm:items-center">
                <Link to="/app" className="ui-button-plain">
                  Open Chat
                </Link>
                <Link to="/ai-chat" className="ui-button-plain">
                  AI Assistant
                </Link>
                <p className="text-sm text-slate-400">
                  Explore the deployed sample UI backed by the same services
                  shipped in this repo.
                </p>
              </div>
            ) : (
              <div className="flex flex-col gap-4">
                <div className="rounded-2xl border border-white/10 bg-white/5 backdrop-blur p-6">
                  <p className="text-white mb-4">
                    🔒 Please sign in to access the additional features
                  </p>
                  <LoginButton />
                </div>
              </div>
            )}
          </section>

          <section className="grid gap-6 sm:grid-cols-2">
            {[
              {
                icon: "🖥️",
                title: "React UI",
                description:
                  "Vite + React chat interface deployed to Azure Storage static hosting, ready for branding and customization.",
              },
              {
                icon: "⚡",
                title: "Go API",
                description:
                  "High-performance Go API hosted in Azure Container Apps with JWT authentication and WebSocket support.",
              },
              {
                icon: "�",
                title: "Realtime Events",
                description:
                  "Extensible WebSocket-based event system for chat, user presence, and custom event broadcasting.",
              },
              {
                icon: "🌐",
                title: "Application Gateway Ingress",
                description:
                  "Azure Application Gateway with WAF for secure routing, SSL termination, and traffic management.",
              },
              {
                icon: "🏗️",
                title: "Product IaC",
                description:
                  "Terraform that stands up the core stack—Storage, Container Apps, App Gateway, observability hooks—so the launchpad runs end to end.",
              },
              {
                icon: "🪄",
                title: "Bootstrap Scripts",
                description:
                  "Separate Terraform helpers that bootstrap your repo with Azure federated credentials, GitHub secrets, and subscription wiring for new teams.",
              },
              {
                icon: "🤖",
                title: "Sample GitHub Actions",
                description:
                  "CI/CD workflows that build the UI, publish containers, and apply Terraform so you can copy the automation on day one.",
              },
            ].map(({ icon, title, description }) => (
              <div
                key={title}
                className="rounded-2xl border border-white/10 bg-white/5 p-5 text-sm text-slate-300 backdrop-blur"
              >
                <div className="flex items-start gap-3">
                  <span className="text-lg">{icon}</span>
                  <div>
                    <h3 className="text-base font-semibold text-white">
                      {title}
                    </h3>
                    <p className="mt-2 text-sm text-slate-300">{description}</p>
                  </div>
                </div>
              </div>
            ))}
          </section>
        </main>

        <footer className="relative z-10 mx-auto flex w-full max-w-5xl justify-between px-6 pb-12 text-xs text-slate-500">
          <p>© {new Date().getFullYear()} Crew Dune Launchpad</p>
          <span className="uppercase tracking-[0.35em]">Ready to wire</span>
        </footer>
      </div>
    </>
  );
}
