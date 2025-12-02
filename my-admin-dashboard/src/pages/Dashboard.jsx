// src/pages/Dashboard.jsx
import AdminLayout from "../layouts/AdminLayout";
import { useFirestore } from "../hooks/useFirestore";

export default function Dashboard() {
  const { data: users } = useFirestore("users");
  const { data: artifacts } = useFirestore("artifacts"); // assuming your Firestore collection is "artifacts"

  // Filter only annotation artifacts
  const annotations = artifacts.filter(
    (a) => a.type === "annotation" && typeof a.annotationText === "string"
  );

  return (
    <AdminLayout>
      <h1 className="text-2xl font-bold mb-6">Dashboard</h1>

      {/* Scenes with Annotations */}
      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-4">Scenes with Annotations</h2>
        {annotations.length === 0 ? (
          <p>No annotations found.</p>
        ) : (
          <ul className="list-disc pl-6">
            {annotations.map((a) => (
              <li key={a.id} className="mb-2">
                <strong>Scene ID:</strong> {a.sceneId} <br />
                <strong>Annotation:</strong> {a.annotationText}
              </li>
            ))}
          </ul>
        )}
      </div>

      {/* Users list */}
      <div>
        <h2 className="text-xl font-semibold mb-4">Users</h2>
        {users.length === 0 ? (
          <p>No users found.</p>
        ) : (
          <ul className="list-disc pl-6">
            {users.map((u) => (
              <li key={u.id}>
                <strong>Email:</strong> {u.email} <br />
                <strong>Username:</strong> {u.username}
              </li>
            ))}
          </ul>
        )}
      </div>
    </AdminLayout>
  );
}
