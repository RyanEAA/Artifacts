// import { useState } from "react";
// import AdminLayout from "../layouts/AdminLayout";
// import { useFirestore } from "../hooks/useFirestore";
// import { doc, updateDoc, deleteDoc } from "firebase/firestore";
// import { db } from "../firebaseConfig";
// import { useAuth } from "../hooks/useAuth";

// export default function Artifacts() {
//   const { data: artifacts = [] } = useFirestore("artifacts");
//   const { user } = useAuth();
//   const [censoringId, setCensoringId] = useState(null);

//   const art_annotations = artifacts.filter(
//     (a) => a.type?.toLowerCase() === "annotation" && a.annotationText !== "[CENSORED]" && a.annotationText !== ""
//   );
//   const censored_annotations = artifacts.filter(
//     (a) => a.type?.toLowerCase() === "annotation" && (a.annotationText === "[CENSORED]")
//   );
//   const empty_annotations = artifacts.filter(
//     (a) => a.type?.toLowerCase() === "annotation" && (a.annotationText === "")
//   );

//   const openCensorModal = (artifact) => {
//     setCensoringId(artifact.id);
//   };

//   const censorArtifact = async () => {
//     try {
//       await updateDoc(doc(db, "artifacts", censoringId), {
//         annotationText: "[CENSORED]",
//       });
//       setCensoringId(null);
//       alert("Annotation censored!");
//     } catch (err) {
//       console.error("Censor failed:", err);
//       alert("Failed to censor annotation.");
//     }
//   };

//   const deleteArtifact = async (id) => {
//     if (!confirm("Are you sure you want to delete this artifact?")) return;
//     try {
//       await deleteDoc(doc(db, "artifacts", id));
//       setCensoringId(null);
//       alert("Artifact deleted!");
//     } catch (err) {
//       console.error("Delete failed:", err);
//       alert("Failed to delete artifact.");
//     }
//   };

//   return (
//     <AdminLayout>
//       <h1 className="text-2xl font-bold mb-6 text-textPrimary">Artifacts</h1>

//       {/* Artifacts with text */}
//       <section className="bg-surface border border-border rounded-lg p-6">
//           <h2 className="text-xl font-semibold mb-4 text-textPrimary">Artifacts with Text</h2>
//         {art_annotations.length === 0 ? (
//           <p className="text-textSecondary">No Artifacts found.</p>
//         ) : (
//           <ul className="space-y-2 text-textSecondary">
//             {art_annotations.map((a) => {
//               const canModerate =
//                 !!user && (a.ownerUid === user.uid || user.isAdmin === true);

//               return (
//                 <li
//                   key={a.id}
//                   className="border-b border-border pb-2 mb-2 flex flex-col md:flex-row md:justify-between md:items-center"
//                 >
//                   <div>
//                     <span className="text-textPrimary font-medium">
//                       Annotation:
//                     </span>{" "}
//                     {a.annotationText}
//                     <br />
//                     <span className="font-medium text-textPrimary">
//                       Annotation ID:
//                     </span>{" "}
//                     {a.id}
//                     <br />
//                     <span className="font-medium text-textPrimary">
//                       Date Created:
//                     </span>{" "}
//                     {a.createdAt?.toDate().toLocaleString() || "N/A"}
//                   </div>
//                   {canModerate && (
//                     <button
//                       className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
//                       onClick={() => openCensorModal(a)}
//                     >
//                       Censor / Delete
//                     </button>
//                   )}
//                 </li>
//               );
//             })}
//           </ul>
//         )}
//       </section>
      
//       {/* Section for no text annotation */}
//       <section className="bg-surface border border-border rounded-lg p-6 mt-6">
//           <h2 className="text-xl font-semibold mb-4 text-textPrimary">Empty Annotations</h2>
//         {empty_annotations.length === 0 ? (
//           <p className="text-textSecondary">No Empty Artifacts found.</p>
//         ) : (
//           <ul className="space-y-2 text-textSecondary">
//             {empty_annotations.map((a) => {
//               const canModerate =
//                 !!user && (a.ownerUid === user.uid || user.isAdmin === true);

//               return (
//                 <li
//                   key={a.id}
//                   className="border-b border-border pb-2 mb-2 flex flex-col md:flex-row md:justify-between md:items-center"
//                 >
//                   <div>
//                     <span className="text-textPrimary font-medium">
//                       Annotation:
//                     </span>{" "}
//                     {a.annotationText}
//                     <br />
//                     <span className="font-medium text-textPrimary">
//                       Annotation ID:
//                     </span>{" "}
//                     {a.id}
//                     <br />
//                     <span className="font-medium text-textPrimary">
//                       Date Created:
//                     </span>{" "}
//                     {a.createdAt?.toDate().toLocaleString() || "N/A"}
//                   </div>
//                   {canModerate && (
//                     <button
//                       className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
//                       onClick={() => openCensorModal(a)}
//                     >
//                       Censor / Delete
//                     </button>
//                   )}
//                 </li>
//               );
//             })}
//           </ul>
//         )}
//       </section>

//       {/* Censored annotations section */}
//       <section className="bg-surface border border-border rounded-lg p-6 mt-6">
//           <h2 className="text-xl font-semibold mb-4 text-textPrimary">Censored Annotations</h2>
//         {censored_annotations.length === 0 ? (
//           <p className="text-textSecondary">No Censored Artifacts found.</p>
//         ) : (
//           <ul className="space-y-2 text-textSecondary">
//             {censored_annotations.map((a) => {
//               const canModerate =
//                 !!user && (a.ownerUid === user.uid || user.isAdmin === true);

//               return (
//                 <li
//                   key={a.id}
//                   className="border-b border-border pb-2 mb-2 flex flex-col md:flex-row md:justify-between md:items-center"
//                 >
//                   <div>
//                     <span className="text-textPrimary font-medium">
//                       Annotation:
//                     </span>{" "}
//                     {a.annotationText}
//                     <br />
//                     <span className="font-medium text-textPrimary">
//                       Annotation ID:
//                     </span>{" "}
//                     {a.id}
//                     <br />
//                     <span className="font-medium text-textPrimary">
//                       Date Created:
//                     </span>{" "}
//                     {a.createdAt?.toDate().toLocaleString() || "N/A"}
//                   </div>
//                   {canModerate && (
//                     <button
//                       className="mt-2 md:mt-0 px-2 py-1 bg-blue-500 text-white rounded"
//                       onClick={() => openCensorModal(a)}
//                     >
//                       Censor / Delete
//                     </button>
//                   )}
//                 </li>
//               );
//             })}
//           </ul>
//         )}
//       </section>

//       {/* Censor/Delete Modal */}
//       {censoringId && (
//         <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
//           <div className="bg-white p-6 rounded-lg w-96">
//             <h2 className="text-lg font-bold mb-4 text-black">
//               Moderate Annotation
//             </h2>

//             <p className="text-black mb-4">
//               You can censor this annotation or delete it permanently.
//             </p>

//             <div className="flex justify-end space-x-2">
//               <button
//                 className="px-3 py-1 bg-red-500 text-white rounded"
//                 onClick={() => deleteArtifact(censoringId)}
//               >
//                 Delete
//               </button>
//               <button
//                 className="px-3 py-1 bg-yellow-500 text-white rounded"
//                 onClick={censorArtifact}
//               >
//                 Censor
//               </button>
//               <button
//                 className="px-3 py-1 bg-gray-300 rounded"
//                 onClick={() => setCensoringId(null)}
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

import { useState, useEffect } from "react";
import AdminLayout from "../layouts/AdminLayout";
import { doc, updateDoc, deleteDoc, collection, onSnapshot, query, orderBy } from "firebase/firestore";
import { db } from "../firebaseConfig";
import { useAuth } from "../hooks/useAuth";

export default function Artifacts() {
  const { user } = useAuth();
  const [artifacts, setArtifacts] = useState([]);
  const [censoringId, setCensoringId] = useState(null);

  // REAL-TIME LISTENER ADDED HERE
  useEffect(() => {
    const q = query(
      collection(db, "artifacts"),
      orderBy("createdAt", "desc")
    );

    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const data = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        setArtifacts(data);
      },
      (error) => {
        console.error("Listener error:", error);
      }
    );

    return () => unsubscribe();
  }, []);
  // END LISTENER

  const art_annotations = artifacts.filter(
    (a) =>
      a.type?.toLowerCase() === "annotation" &&
      a.annotationText !== "[CENSORED]" &&
      a.annotationText !== ""
  );

  const censored_annotations = artifacts.filter(
    (a) =>
      a.type?.toLowerCase() === "annotation" &&
      a.annotationText === "[CENSORED]"
  );

  const empty_annotations = artifacts.filter(
    (a) =>
      a.type?.toLowerCase() === "annotation" &&
      a.annotationText === ""
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
        <h2 className="text-xl font-semibold mb-4 text-textPrimary">
          Artifacts with Text
        </h2>
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
                    <br />
                    <span className="font-medium text-textPrimary">
                      Date Created:
                    </span>{" "}
                    {a.createdAt?.toDate().toLocaleString() || "N/A"}
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
        <h2 className="text-xl font-semibold mb-4 text-textPrimary">
          Empty Annotations
        </h2>
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
                    <br />
                    <span className="font-medium text-textPrimary">
                      Date Created:
                    </span>{" "}
                    {a.createdAt?.toDate().toLocaleString() || "N/A"}
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
        <h2 className="text-xl font-semibold mb-4 text-textPrimary">
          Censored Annotations
        </h2>
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
                    <br />
                    <span className="font-medium text-textPrimary">
                      Date Created:
                    </span>{" "}
                    {a.createdAt?.toDate().toLocaleString() || "N/A"}
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

      {/* Modal stays unchanged */}
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