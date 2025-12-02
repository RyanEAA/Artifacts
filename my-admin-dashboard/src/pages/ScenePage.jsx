// src/pages/ScenePage.jsx
import { useParams } from "react-router-dom";
import { useEffect, useState } from "react";
import { doc, getDoc } from "firebase/firestore";
import { db } from "../firebaseConfig";
import AdminLayout from "../layouts/AdminLayout";

export default function ScenePage() {
  const { id } = useParams();
  const [scene, setScene] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchScene = async () => {
      try {
        const snapshot = await getDoc(doc(db, "scenes", id));

        if (!snapshot.exists()) {
          setScene(null);
          setLoading(false);
          return;
        }

        const data = snapshot.data();

        const annotations = Array.isArray(data.annotations)
          ? data.annotations.filter(a => a.type === "annotation" && typeof a.annotationText === "string")
          : [];

        if (annotations.length === 0) {
          setScene(null);
        } else {
          setScene({ ...data, annotations });
        }

        setLoading(false);
      } catch (err) {
        console.error("Error fetching scene:", err);
        setScene(null);
        setLoading(false);
      }
    };

    fetchScene();
  }, [id]);

  if (loading) {
    return (
      <AdminLayout>
        <div className="p-6 text-lg font-semibold">Loading scene…</div>
      </AdminLayout>
    );
  }

  if (!scene) {
    return (
      <AdminLayout>
        <div className="p-6 text-red-600 font-semibold">
          Scene not found or has no annotations.
        </div>
      </AdminLayout>
    );
  }

  return (
    <AdminLayout>
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">{scene.name}</h1>

        <div className="bg-white p-4 shadow rounded-lg mb-6">
          <p><strong>Owner UID:</strong> {scene.ownerUid}</p>
          <p><strong>Bytes:</strong> {scene.bytes}</p>
          <p><strong>Updated At:</strong> {scene.updatedAt?.toDate?.().toLocaleString()}</p>
        </div>

        <div className="bg-gray-100 p-4 rounded-lg shadow">
          <h2 className="text-xl font-semibold mb-3">Annotations</h2>
          <ul className="list-disc pl-5 space-y-1">
            {scene.annotations.map(a => (
              <li key={a.id}>{a.annotationText}</li>
            ))}
          </ul>
        </div>
      </div>
    </AdminLayout>
  );
}
