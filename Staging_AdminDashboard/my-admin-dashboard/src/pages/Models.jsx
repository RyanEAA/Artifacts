import AdminLayout from "../layouts/AdminLayout";
import { useState } from "react";
import { useAuth } from "../hooks/useAuth";
import { storage, db } from "../firebaseConfig";
import {
  ref,
  uploadBytesResumable,
  getDownloadURL,
  deleteObject,
} from "firebase/storage";
import {
  collection,
  addDoc,
  deleteDoc,
  doc,
  serverTimestamp,
} from "firebase/firestore";
import { useFirestore } from "../hooks/useFirestore";

export default function Models() {
  const { user } = useAuth();
  const { data: models = [] } = useFirestore("models");

  const [file, setFile] = useState(null);
  const [progress, setProgress] = useState(0);
  const [selectedId, setSelectedId] = useState(null);

  // Upload helper
  const uploadFile = (fileRef, fileData) =>
    new Promise((resolve, reject) => {
      const task = uploadBytesResumable(fileRef, fileData);

      task.on(
        "state_changed",
        (snapshot) => {
          const prog =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          setProgress(Math.round(prog));
        },
        (error) => reject(error),
        async () => {
          const url = await getDownloadURL(fileRef);
          resolve(url);
        }
      );
    });

  const handleUpload = async () => {
    if (!file) {
      alert("Upload a USDZ file.");
      return;
    }

    if (!file.name.toLowerCase().endsWith(".usdz")) {
      alert("Only .usdz files allowed.");
      return;
    }

    try {
      const timestamp = Date.now();
      const modelPath = `models/${timestamp}_${file.name}`;
      const modelRef = ref(storage, modelPath);

      const modelUrl = await uploadFile(modelRef, file);

      await addDoc(collection(db, "models"), {
        name: file.name,
        url: modelUrl,
        modelPath,
        ownerUid: user?.uid || null,
        createdAt: serverTimestamp(),
      });

      // Reset
      setFile(null);
      setProgress(0);

      alert("Uploaded!");
    } catch (err) {
      console.error(err);
      alert("Upload failed");
    }
  };

  const handleDelete = async (model) => {
    if (!window.confirm("Delete this model?")) return;

    try {
      await deleteDoc(doc(db, "models", model.id));

      if (model.modelPath) {
        await deleteObject(ref(storage, model.modelPath));
      }
    } catch (err) {
      console.error(err);
      alert("Delete failed");
    }
  };

  return (
    <AdminLayout>
      <h1 className="text-2xl font-bold mb-6 text-textPrimary">
        3D Models
      </h1>

      {/* Upload Section */}
      <section className="bg-surface p-6 rounded-lg mb-6">
        <div className="flex flex-col gap-3">

          {/* Drag + Click Upload */}
          <div
            onClick={() =>
              document.getElementById("fileInput").click()
            }
            onDrop={(e) => {
              e.preventDefault();
              const droppedFile = e.dataTransfer.files[0];

              if (
                droppedFile?.name
                  .toLowerCase()
                  .endsWith(".usdz")
              ) {
                setFile(droppedFile);
              } else {
                alert("Only .usdz files allowed.");
              }
            }}
            onDragOver={(e) => e.preventDefault()}
            className="border-2 border-dashed p-8 text-center cursor-pointer rounded-lg"
          >
            <p className="font-medium">
              Drag & drop USDZ here
            </p>
            <p className="text-sm text-gray-500">
              or click to select file
            </p>

            <input
              id="fileInput"
              type="file"
              accept=".usdz"
              className="hidden"
              onChange={(e) =>
                setFile(e.target.files[0])
              }
            />
          </div>

          {/* Selected file */}
          {file && (
            <p className="text-sm">
              📦 {file.name}
            </p>
          )}

          {/* Upload button */}
          <button
            onClick={handleUpload}
            className="bg-blue-500 text-white px-4 py-2 rounded"
          >
            Upload
          </button>

          {/* Progress bar */}
          {progress > 0 && (
            <div className="w-full bg-gray-200 rounded">
              <div
                className="bg-blue-500 text-xs text-white p-1 rounded"
                style={{ width: `${progress}%` }}
              >
                {progress}%
              </div>
            </div>
          )}
        </div>
      </section>

      {/* Models Grid */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {models.map((m) => (
          <div
            key={m.id}
            onClick={() => setSelectedId(m.id)}
            className={`border rounded-lg overflow-hidden cursor-pointer transition ${
              selectedId === m.id
                ? "border-blue-500 ring-2 ring-blue-400"
                : "border-border"
            }`}
          >
            <div className="p-3">
              <p className="text-sm font-medium truncate">
                {m.name}
              </p>

              <div className="flex justify-between mt-2">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDelete(m);
                  }}
                  className="text-red-500 text-sm"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        ))}
      </section>
    </AdminLayout>
  );
}