import { Link } from "react-router-dom";

export default function Unauthorized() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="bg-surface border border-border rounded-lg p-8 max-w-md text-center">
        <h1 className="text-2xl font-bold text-textPrimary mb-2">
          Access Denied
        </h1>
        <p className="text-textSecondary mb-6">
          You don’t have permission to view this page.
        </p>

        <Link
          to="/dashboard"
          className="inline-block px-4 py-2 rounded bg-blue-600 text-white hover:bg-blue-700 transition"
        >
          Go back to dashboard
        </Link>
      </div>
    </div>
  );
}
