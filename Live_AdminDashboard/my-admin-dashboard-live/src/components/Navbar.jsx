import { Link } from "react-router-dom";

export default function Navbar({ user, logout }) {
  return (
    <header className="flex items-center justify-between px-6 py-4 bg-surface border-b border-border text-textPrimary">
      <h2 className="text-xl font-semibold">
        Welcome, {user?.email}
      </h2>

      <Link to="/" onClick={logout} className="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-700">
        Logout
      </Link>
    </header>
  );
}

