import Sidebar from "../components/Sidebar";
import Navbar from "../components/Navbar";
import { useAuth } from "../hooks/useAuth";

export default function AdminLayout({ children }) {
  const { user, logout } = useAuth();

  if (!user) return <div>Loading...</div>;

  return (
    <div className="flex h-screen">
      <Sidebar />

      <div className="flex-1 flex flex-col">
        <Navbar user={user} logout={logout} />

        <main className="p-6 bg-gray-100 flex-1 overflow-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
