import { useEffect, useState } from "react";
import { collection, getDocs, query, where } from "firebase/firestore";
import { getDownloadURL, ref } from "firebase/storage";
import { db, storage } from "../firebaseConfig";
import AdminLayout from "../layouts/AdminLayout";
import { Link } from "react-router-dom";

export default function ScenesList() {
  const [scenes, setScenes] = useState([]);

  useEffect(() => {
    const loadScenes = async () => {
      // Fetch all annotations of type "annotation"
      const annotationsSnap = await getDocs(
        query(collection(db, "annotations"), where("type", "==", "annotation"))
      );
      const annotations = annotationsSnap.docs.map(doc => doc.data());

      // Build a set of sceneIds that have at least one annotation
      const sceneIdsWithAnnotations = new Set(
        annotations.map(a => a.sceneId)
      );

      // Fetch all scenes
      const scenesSnap = await getDocs(collection(db, "scenes"));
      const list = [];

      for (const docSnap of scenesSnap.docs) {
        if (sceneIdsWithAnnotations.has(docSnap.id)) {
          const data = docSnap.data();
          let imageUrl = "";

          if (data.storagePath) {
            try {
              imageUrl = await getDownloadURL(ref(storage, data.storagePath));
            } catch {
              imageUrl = "";
            }
          }

          list.push({
            id: docSnap.id,
            ...data,
            imageUrl,
          });
        }
      }

      setScenes(list);
    };

    loadScenes();
  }, []);

  return (
    <AdminLayout>
      <h1 className="text-3xl font-semibold mb-6">Scenes with Annotations</h1>

      {scenes.length === 0 ? (
        <p>No scenes with annotations found.</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {scenes.map(scene => (
            <div
              key={scene.id}
              className="bg-white p-4 rounded-xl shadow hover:shadow-lg transition"
            >
              {scene.imageUrl ? (
                <img
                  src={scene.imageUrl}
                  alt={scene.name}
                  className="w-full h-40 object-cover rounded-md mb-3"
                />
              ) : (
                <div className="w-full h-40 bg-gray-200 rounded-md mb-3 flex items-center justify-center text-gray-500">
                  No Image
                </div>
              )}

              <h2 className="text-lg font-semibold">{scene.name}</h2>
              <Link
                to={`/dashboard/scene/${scene.id}`}
                className="block text-center bg-blue-600 text-white py-2 rounded hover:bg-blue-700"
              >
                Open Scene
              </Link>
            </div>
          ))}
        </div>
      )}
    </AdminLayout>
  );
}
