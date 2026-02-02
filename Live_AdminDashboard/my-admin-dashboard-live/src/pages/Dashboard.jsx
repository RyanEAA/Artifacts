import AdminLayout from "../layouts/AdminLayout";
import { useFirestore } from "../hooks/useFirestore";
import { Link } from "react-router-dom";

export default function Dashboard() {
  const { data: users } = useFirestore("users");
  const { data: artifacts } = useFirestore("artifacts");

  const annotations = artifacts.filter(a => a.type === "annotation");

  return (
    <AdminLayout>
      <h1 className="text-2xl font-bold mb-6 text-textPrimary">Dashboard</h1>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Artifacts with Annotations */}
        <section className="bg-surface border border-border rounded-lg p-6">
          <h2 className="flex items-center text-xl font-semibold mb-4 text-textPrimary">
            Artifacts with Annotations
            <Link
              to="/dashboard/artifacts"
              className="ml-auto px-3 py-1 rounded bg-blue-500 text-white hover:bg-blue-700 transition"
            >
              Edit Artifacts
            </Link>
          </h2>

          {annotations.length === 0 ? (
            <p className="text-textSecondary">No artifacts found.</p>
          ) : (
            <ul className="list-disc pl-6 space-y-2 text-textSecondary">
              {annotations.map(a => (
                <li key={a.id}>
                  <span className="font-medium text-textPrimary">Artifact ID:</span>{" "}
                  {a.id}
                  <br />
                  <span className="font-medium text-textPrimary">Annotation:</span>{" "}
                  {a.annotationText}
                </li>
              ))}
            </ul>
          )}
        </section>

        {/* Users list */}
        <section className="bg-surface border border-border rounded-lg p-6">
          <h2 className="flex items-center text-xl font-semibold mb-4 text-textPrimary">Users 
            <Link
              to="/dashboard/users"
              className="ml-auto px-3 py-1 rounded bg-blue-500 text-white hover:bg-blue-700 transition"
            >
              Edit Users
            </Link>
          </h2>

          {users.length === 0 ? (
            <p className="text-textSecondary">No users found.</p>
          ) : (
            <ul className="list-disc pl-6 space-y-2 text-textSecondary">
              {users.map(u => (
                <li key={u.id}>
                  <span className="font-medium text-textPrimary">Email:</span>{" "}
                  {u.email}
                  <br />
                  <span className="font-medium text-textPrimary">Username:</span>{" "}
                  {u.username}
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </AdminLayout>
  );
}
