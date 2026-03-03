// import { useState } from "react";
// import AdminLayout from "../layouts/AdminLayout";
// import { useFirestore } from "../hooks/useFirestore";
// import { doc, updateDoc, deleteDoc } from "firebase/firestore";
// import { db } from "../firebaseConfig"; // Points to your Firestore instance
// import { useAuth } from "../hooks/useAuth"; // hypothetical hook to get current q


// export default function Artifacts() {
//   const { data: artifacts = [] } = useFirestore("artifacts");
//   const { user } = useAuth(); // current logged-in user with uid and isAdmin
//   const [editingId, setEditingId] = useState(null);
//   const [newText, setNewText] = useState("");

//   const art_annotations = artifacts.filter(
//     (a) => a.type?.toLowerCase() === "annotation"
//   );

//   console.log("artifacts:", artifacts);
//   console.log("annotations:", art_annotations);

//   const openEditor = (artifact) => {
//     setEditingId(artifact.id);
//     setNewText(artifact.annotationText);
//   };

//   const saveChanges = async () => {
//     try {
//       await updateDoc(doc(db, "artifacts", editingId), {
//         annotationText: newText,
//       });
//       setEditingId(null);
//       alert("Annotation updated!");
//     } catch (err) {
//       console.error("Update failed:", err);
//       alert("Failed to update annotation.");
//     }
//   };

//   const deleteArtifact = async (id) => {
//     if (!confirm("Are you sure you want to delete this artifact?")) return;
//     try {
//       await deleteDoc(doc(db, "artifacts", id));
//       setEditingId(null);
//       alert("Artifact deleted!");
//     } catch (err) {
//       console.error("Delete failed:", err);
//       alert("Failed to delete artifact.");
//     }
//   };

//   return (
//     <AdminLayout>
//       <h1 className="text-2xl font-bold mb-6 text-textPrimary">Artifacts</h1>

//       <section className="bg-surface border border-border rounded-lg p-6">
//         {art_annotations.length === 0 ? (
//           <p className="text-textSecondary">No Artifacts found.</p>
//         ) : (
//           <ul className="space-y-2 text-textSecondary">
//             {art_annotations.map((a) => {
//               const canEdit = !!user && (a.ownerUid === user.uid || user.isAdmin === true);
//               // console.log("Artifact:", a, "Can Edit:", canEdit);
//               // console.log("Is User Admin:", user.isAdmin," User ID:" ,user.uid);
//               return (
//                 <li key={a.id} className="border-b border-border pb-2 mb-2flex flex-col md:flex-row md:justify-between md:items-center">
//                   <div>
//                     <span className="text-textPrimary font-medium">Annotation:</span>{" "}
//                     {a.annotationText}
//                     <br />
//                     <span className="font-medium text-textPrimary">Annotation Id:</span>{" "}
//                     {a.id}
//                   </div>

//                   {canEdit && (
//                     <button
//                       className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
//                       onClick={() => openEditor(a)}
//                     >Edit / Delete
//                     </button>
//                   )}
//                 </li>
//               );
//             })}
//           </ul>
//         )}
//       </section>

//       {/* Edit/Delete Modal */}
//       {editingId && (
//         <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
//           <div className="bg-white p-6 rounded-lg w-96">
//             <h2 className="text-lg font-bold mb-4 text-black">Edit Annotation</h2>
//             <textarea
//               className="w-full border border-border rounded p-2 mb-4 text-black"
//               value={newText}
//               onChange={(e) => setNewText(e.target.value)}
//             />
//             <div className="flex justify-end space-x-2">
//               <button
//                 className="px-3 py-1 bg-red-500 text-white rounded"
//                 onClick={() => deleteArtifact(editingId)}
//               >
//                 Delete
//               </button>
//               <button
//                 className="px-3 py-1 bg-green-500 text-white rounded"
//                 onClick={saveChanges}
//               >
//                 Save
//               </button>
//               <button
//                 className="px-3 py-1 bg-gray-300 rounded"
//                 onClick={() => setEditingId(null)}
//               >
//                 Cancel
//               </button>
//             </div>
//           </div>
//         </div>
//       )}
//     </AdminLayout>
//   );
// }
import { useState } from "react";
import AdminLayout from "../layouts/AdminLayout";
import { useFirestore } from "../hooks/useFirestore";
import { doc, updateDoc, deleteDoc } from "firebase/firestore";
import { db } from "../firebaseConfig";
import { useAuth } from "../hooks/useAuth";

export default function Artifacts() {
  const { data: artifacts = [] } = useFirestore("artifacts");
  const { user } = useAuth();
  const [censoringId, setCensoringId] = useState(null);

  const art_annotations = artifacts.filter(
    (a) => a.type?.toLowerCase() === "annotation" && a.annotationText !== "[CENSORED]" && a.annotationText !== ""
  );
  const censored_annotations = artifacts.filter(
    (a) => a.type?.toLowerCase() === "annotation" && (a.annotationText === "[CENSORED]")
  );
  const empty_annotations = artifacts.filter(
    (a) => a.type?.toLowerCase() === "annotation" && (a.annotationText === "")
  );

  const openCensorModal = (artifact) => {
    setCensoringId(artifact.id);
  };

  const censorArtifact = async () => {
    try {
      await updateDoc(doc(db, "artifacts", censoringId), {
        annotationText: "[CENSORED]",
      });
      setCensoringId(null);
      alert("Annotation censored!");
    } catch (err) {
      console.error("Censor failed:", err);
      alert("Failed to censor annotation.");
    }
  };

  const deleteArtifact = async (id) => {
    if (!confirm("Are you sure you want to delete this artifact?")) return;
    try {
      await deleteDoc(doc(db, "artifacts", id));
      setCensoringId(null);
      alert("Artifact deleted!");
    } catch (err) {
      console.error("Delete failed:", err);
      alert("Failed to delete artifact.");
    }
  };

  return (
    <AdminLayout>
      <h1 className="text-2xl font-bold mb-6 text-textPrimary">Artifacts</h1>

      {/* Artifacts with text */}
      <section className="bg-surface border border-border rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4 text-textPrimary">Artifacts with Text</h2>
        {art_annotations.length === 0 ? (
          <p className="text-textSecondary">No Artifacts found.</p>
        ) : (
          <ul className="space-y-2 text-textSecondary">
            {art_annotations.map((a) => {
              const canModerate =
                !!user && (a.ownerUid === user.uid || user.isAdmin === true);

              return (
                <li
                  key={a.id}
                  className="border-b border-border pb-2 mb-2 flex flex-col md:flex-row md:justify-between md:items-center"
                >
                  <div>
                    <span className="text-textPrimary font-medium">
                      Annotation:
                    </span>{" "}
                    {a.annotationText}
                    <br />
                    <span className="font-medium text-textPrimary">
                      Annotation ID:
                    </span>{" "}
                    {a.id}
                  </div>
                  {canModerate && (
                    <button
                      className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
                      onClick={() => openCensorModal(a)}
                    >
                      Censor / Delete
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>
      
      {/* Section for no text annotation */}
      <section className="bg-surface border border-border rounded-lg p-6 mt-6">
          <h2 className="text-xl font-semibold mb-4 text-textPrimary">Empty Annotations</h2>
        {empty_annotations.length === 0 ? (
          <p className="text-textSecondary">No Empty Artifacts found.</p>
        ) : (
          <ul className="space-y-2 text-textSecondary">
            {empty_annotations.map((a) => {
              const canModerate =
                !!user && (a.ownerUid === user.uid || user.isAdmin === true);

              return (
                <li
                  key={a.id}
                  className="border-b border-border pb-2 mb-2 flex flex-col md:flex-row md:justify-between md:items-center"
                >
                  <div>
                    <span className="text-textPrimary font-medium">
                      Annotation:
                    </span>{" "}
                    {a.annotationText}
                    <br />
                    <span className="font-medium text-textPrimary">
                      Annotation ID:
                    </span>{" "}
                    {a.id}
                  </div>
                  {canModerate && (
                    <button
                      className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
                      onClick={() => openCensorModal(a)}
                    >
                      Censor / Delete
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {/* Censored annotations section */}
      <section className="bg-surface border border-border rounded-lg p-6 mt-6">
          <h2 className="text-xl font-semibold mb-4 text-textPrimary">Censored Annotations</h2>
        {censored_annotations.length === 0 ? (
          <p className="text-textSecondary">No Censored Artifacts found.</p>
        ) : (
          <ul className="space-y-2 text-textSecondary">
            {censored_annotations.map((a) => {
              const canModerate =
                !!user && (a.ownerUid === user.uid || user.isAdmin === true);

              return (
                <li
                  key={a.id}
                  className="border-b border-border pb-2 mb-2 flex flex-col md:flex-row md:justify-between md:items-center"
                >
                  <div>
                    <span className="text-textPrimary font-medium">
                      Annotation:
                    </span>{" "}
                    {a.annotationText}
                    <br />
                    <span className="font-medium text-textPrimary">
                      Annotation ID:
                    </span>{" "}
                    {a.id}
                  </div>
                  {canModerate && (
                    <button
                      className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
                      onClick={() => openCensorModal(a)}
                    >
                      Censor / Delete
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {/* Censor/Delete Modal */}
      {censoringId && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg w-96">
            <h2 className="text-lg font-bold mb-4 text-black">
              Moderate Annotation
            </h2>

            <p className="text-black mb-4">
              You can censor this annotation or delete it permanently.
            </p>

            <div className="flex justify-end space-x-2">
              <button
                className="px-3 py-1 bg-red-500 text-white rounded"
                onClick={() => deleteArtifact(censoringId)}
              >
                Delete
              </button>
              <button
                className="px-3 py-1 bg-yellow-500 text-white rounded"
                onClick={censorArtifact}
              >
                Censor
              </button>
              <button
                className="px-3 py-1 bg-gray-300 rounded"
                onClick={() => setCensoringId(null)}
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
