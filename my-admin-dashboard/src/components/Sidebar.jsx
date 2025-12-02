export default function Sidebar() {
  return (
    <aside className="w-64 h-full bg-gray-900 text-gray-200 p-4 flex flex-col">
      <h1 className="text-3xl font-bold mb-8">Admin</h1>

      <nav className="space-y-2">
        <a href="/dashboard" className="block px-3 py-2 rounded hover:bg-gray-700">Dashboard</a>

        <a href="/dashboard/users" className="block px-3 py-2 rounded hover:bg-gray-700">Users</a>

        <a href="/dashboard/scenes" className="block px-3 py-2 rounded hover:bg-gray-700">Scenes</a>
      </nav>


      <div className="mt-auto text-xs text-gray-500">
        © {new Date().getFullYear()}
      </div>
    </aside>
  );
}
