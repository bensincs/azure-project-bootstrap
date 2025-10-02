# UI Project Structure

```
src/
├── components/       # Reusable UI components
│   └── AnimatedBackground.tsx
├── pages/           # Page components (for routing)
├── hooks/           # Custom React hooks
├── lib/             # Utility functions and helpers
├── App.tsx          # Root component
├── main.tsx         # Entry point
├── index.css        # Global styles (Tailwind)
└── vite-env.d.ts    # TypeScript declarations
```

## Folder Guidelines

### `components/`
Reusable UI components that can be used across multiple pages.
- Should be pure and focused on presentation
- Example: Button, Card, Modal, AnimatedBackground

### `pages/`
Page-level components, typically one per route.
- Example: Home, About, Dashboard

### `hooks/`
Custom React hooks for shared logic.
- Example: useAuth, useFetch, useLocalStorage

### `lib/`
Utility functions, constants, and helpers.
- Example: formatters, validators, API clients

## Scripts

- `yarn dev` - Start development server
- `yarn build` - Build for production
- `yarn preview` - Preview production build
- `yarn deploy` - Build and deploy to Azure Storage
