import Sidebar from "../components/Sidebar";
import Navbar from "../components/Navbar";
import { useAuth } from "../hooks/useAuth";

export default function AdminLayout({ children }) {
  const { user, logout } = useAuth();

  if (!user) return <div>Loading...</div>;

  return (
    <div className="flex min-h-screen">
      <Sidebar />

      <div className="flex-1 flex flex-col">
        <Navbar user={user} logout={logout} />

        <main className="flex-1 bg-background p-6 overflow-auto">
          <div className="max-w-7xl mx-auto text-textPrimary">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
