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
  const { user, loading } = useAuth();
  const { data: models = [] } = useFirestore("models");

  const [selectedId, setSelectedId] = useState(null);
  const [showCreateForm, setShowCreateForm] = useState(false);

  const [category, setCategory] = useState("");
  const [scaleCompensation, setScaleCompensation] = useState("");
  const [file, setFile] = useState(null);
  const [progress, setProgress] = useState(0);
  const [submitting, setSubmitting] = useState(false);

  if (loading) {
    return (
      <AdminLayout>
        <p>Loading...</p>
      </AdminLayout>
    );
  }

  if (!user) {
    return (
      <AdminLayout>
        <p>You must be logged in to manage models.</p>
      </AdminLayout>
    );
  }

  // 🔑 Extract name from filename
  const getNameFromFile = (file) => {
    if (!file) return "";
    return file.name.replace(/\.usdz$/i, "");
  };

  const resetForm = () => {
    setCategory("");
    setScaleCompensation("");
    setFile(null);
    setProgress(0);
    setSubmitting(false);

    const input = document.getElementById("modelFileInput");
    if (input) input.value = "";
  };

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

  const handleCreateModel = async (e) => {
    e.preventDefault();

    if (!file) {
      alert("Please select a USDZ file.");
      return;
    }

    if (!file.name.toLowerCase().endsWith(".usdz")) {
      alert("Only .usdz files are allowed.");
      return;
    }

    if (!category.trim() || !scaleCompensation.trim()) {
      alert("Please fill out category and scale compensation.");
      return;
    }

    const name = getNameFromFile(file);

    try {
      setSubmitting(true);


      await addDoc(collection(db, "models"), {
        name: name.replace(".usdz", ""),
        category: category.trim(),
        scaleCompensation: scaleCompensation.trim(),
      });

      alert("Model created successfully.");
      resetForm();
      setShowCreateForm(false);
    } catch (err) {
      console.error(err);
      alert("Model creation failed.");
      setSubmitting(false);
    }
  };

  const handleDelete = async (model) => {
    if (!user) {
      alert("You must be logged in.");
      return;
    }

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
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-textPrimary">3D Models</h1>

        <button
          onClick={() => {
            if (showCreateForm) {
              resetForm();
              setShowCreateForm(false);
            } else {
              setShowCreateForm(true);
            }
          }}
          className="bg-blue-500 text-white px-4 py-2 rounded"
        >
          {showCreateForm ? "Cancel" : "Create New Model"}
        </button>
      </div>

      {/* Create Form */}
      {showCreateForm && (
        <section className="bg-surface p-6 rounded-lg mb-6 border border-border">
          <form onSubmit={handleCreateModel} className="flex flex-col gap-4">

            {/* File Upload */}
            <div>
              <label className="block text-sm font-medium mb-1">
                USDZ File
              </label>
              <input
                id="modelFileInput"
                type="file"
                accept=".usdz"
                onChange={(e) => {
                  const selectedFile = e.target.files?.[0] || null;

                  if (
                    selectedFile &&
                    !selectedFile.name.toLowerCase().endsWith(".usdz")
                  ) {
                    alert("Only .usdz files are allowed.");
                    return;
                  }

                  setFile(selectedFile);
                }}
                className="w-full border border-border rounded px-3 py-2"
              />

              {file && (
                <p className="text-sm mt-2">
                  Model name:{" "}
                  <span className="font-medium">
                    {getNameFromFile(file)}
                  </span>
                </p>
              )}
            </div>

            {/* Category */}
            <div>
              <label className="block text-sm font-medium mb-1">
                Category
              </label>
              <input
                type="text"
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                placeholder="adf"
                className="w-full border border-border rounded px-3 py-2"
              />
            </div>

            {/* Scale */}
            <div>
              <label className="block text-sm font-medium mb-1">
                Scale Compensation
              </label>
              <input
                type="text"
                value={scaleCompensation}
                onChange={(e) => setScaleCompensation(e.target.value)}
                placeholder="0.5"
                className="w-full border border-border rounded px-3 py-2"
              />
            </div>

            {/* Progress */}
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

            {/* Submit */}
            <button
              type="submit"
              disabled={submitting}
              className="bg-blue-500 text-white px-4 py-2 rounded disabled:opacity-50"
            >
              {submitting ? "Creating..." : "Create Model"}
            </button>
          </form>
        </section>
      )}

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
              <p className="text-sm font-medium truncate">{m.name}</p>
              <p className="text-xs text-gray-500 mt-1">
                Category: {m.category || "—"}
              </p>
              <p className="text-xs text-gray-500">
                Scale: {m.scaleCompensation || "—"}
              </p>

              <div className="flex justify-between mt-3">
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