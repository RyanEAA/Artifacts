import AdminLayout from "../layouts/AdminLayout";
import { useFirestore } from "../hooks/useFirestore";
import { useState } from "react";
import { useAuth } from "../hooks/useAuth";
import { doc, updateDoc, deleteDoc } from "firebase/firestore";
import { db } from "../firebaseConfig";

export default function Users() {
  const { data: users } = useFirestore("users");
  const { user } = useAuth();
  const [editingId, setEditingId] = useState(null);
  const [newUsername, setNewUsername] = useState("");

  const openEditor = (u) => {
    setEditingId(u.id);
    setNewUsername(u.username);
  };

  const closeEditor = () => {
    setEditingId(null);
    setNewUsername("");
  };

  // const saveChanges = async () => {
  //   try {
  //     await updateDoc(doc(db, "users", editingId), {
  //       username: newUsername,
  //     });
  //     closeEditor();
  //     alert("Username updated!");
  //   } catch (err) {
  //     console.error("Update failed:", err);
  //     alert("Failed to update username.");
  //   }
  // };
  const saveChanges = async () => {
  try {
    const trimmedUsername = newUsername.trim();

    if (!trimmedUsername) {
      alert("Username cannot be empty.");
      return;
    }

    // Check if username already exists (excluding current user)
    const usernameTaken = users.some(
      (u) =>
        u.username.toLowerCase() === trimmedUsername.toLowerCase() &&
        u.id !== editingId
    );

    if (usernameTaken) {
      alert("That username is already in use.");
      return;
    }

    await updateDoc(doc(db, "users", editingId), {
      username: trimmedUsername,
    });

    closeEditor();
    alert("Username updated!");
  } catch (err) {
    console.error("Update failed:", err);
    alert("Failed to update username.");
  }
};


  const deleteUser = async (id) => {
    if (!confirm("Are you sure you want to delete this user?")) return;
    try {
      await deleteDoc(doc(db, "users", id));
      closeEditor();
      alert("User deleted!");
    } catch (err) {
      console.error("Delete failed:", err);
      alert("Failed to delete user.");
    }
  };

  return (
    <AdminLayout>
      <h1 className="text-2xl font-bold mb-6 text-textPrimary">Users</h1>

      <section className="bg-surface border border-border rounded-lg p-6">
        {users.length === 0 ? (
          <p className="text-textSecondary">No users found.</p>
        ) : (
          <ul className="space-y-2 text-textSecondary">
            {users.map((u) => {
              if (u.username === "admin") return null;

              const canEdit =
                user && (u.ownerUid === user.uid || user.isAdmin);

              return (
                <li
                  key={u.id}
                  className="flex items-center justify-between border-b border-border pb-3"
                >
                  <div>
                    <span className="text-textPrimary font-medium">
                      Email:
                    </span>{" "}
                    {u.email}
                    <br />
                    <span className="text-textPrimary font-medium">
                      Username:
                    </span>{" "}
                    {u.username}
                  </div>

                  {canEdit && (
                    <button
                      onClick={() => openEditor(u)}
                      className="ml-4 px-3 py-1 bg-blue-500 text-white rounded whitespace-nowrap hover:bg-blue-600 transition"
                    >
                      Edit / Delete
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {/* MODAL */}
      {editingId && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg w-96">
            <h2 className="text-lg font-bold mb-4 text-black">
              Edit Username
            </h2>

            <textarea
              className="w-full border border-border rounded p-2 mb-4 text-black"
              value={newUsername}
              onChange={(e) => setNewUsername(e.target.value)}
            />

            <div className="flex justify-end gap-2">
              <button
                className="px-3 py-1 bg-red-500 text-white rounded hover:bg-red-600"
                onClick={() => deleteUser(editingId)}
              >
                Delete
              </button>

              <button
                className="px-3 py-1 bg-green-500 text-white rounded hover:bg-green-600"
                onClick={saveChanges}
              >
                Save
              </button>

              <button
                className="px-3 py-1 bg-gray-300 rounded hover:bg-gray-400"
                onClick={closeEditor}
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </AdminLayout>
  );
}