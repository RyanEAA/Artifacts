import { Link } from "react-router-dom";

export default function Sidebar() {
  return (
    <aside className="w-64 bg-surface text-white p-6">
      <nav className="space-y-2">
        <Link to="/dashboard" className="block px-3 py-2 rounded hover:bg-white/20">
          Dashboard
        </Link>
        <Link to="/dashboard/users" className="block px-3 py-2 rounded hover:bg-white/20">
          Users
        </Link>
        <Link to="/dashboard/artifacts" className="block px-3 py-2 rounded hover:bg-white/20">
          Artifacts
        </Link>
      </nav>
    </aside>
  );
}
