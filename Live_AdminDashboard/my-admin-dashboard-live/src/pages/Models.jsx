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
  const [thumbnail, setThumbnail] = useState(null);

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
    setThumbnail(null);
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

    const convertImageToJPG = (file, modelName) => {
      return new Promise((resolve, reject) => {
        const img = new Image();
        const reader = new FileReader();

        reader.onload = (e) => {
          img.src = e.target.result;
        };

        img.onload = () => {
          const canvas = document.createElement("canvas");
          canvas.width = img.width;
          canvas.height = img.height;

          const ctx = canvas.getContext("2d");
          ctx.drawImage(img, 0, 0);

          canvas.toBlob(
            (blob) => {
              if (!blob) {
                reject("Failed to convert image");
                return;
              }

              const newFile = new File(
                [blob],
                `${modelName}.jpg`,
                { type: "image/jpeg" }
              );

              resolve(newFile);
            },
            "image/jpeg",
            0.9
          );
        };

        reader.readAsDataURL(file);
      });
    };

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
      const modelPath = `models/${name}.usdz`;
      const modelRef = ref(storage, modelPath);
      const modelUrl = await uploadFile(modelRef, file);

      let thumbnailPath = null;
      // Upload thumbnail if provided
      if (thumbnail) {
        const convertedImage = await convertImageToJPG(thumbnail, name);

        thumbnailPath = `thumbnails/${name}.jpg`;
        const thumbnailRef = ref(storage, thumbnailPath);

        await uploadFile(thumbnailRef, convertedImage);
}


      await addDoc(collection(db, "models"), {
        name,
        category: category.trim(),
        scaleCompensation: scaleCompensation.trim(),
        url: modelUrl,
        modelPath,
        thumbnailPath,
        ownerUid: user?.uid || null,
        createdAt: serverTimestamp(),
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
      const normalizedName = String(model.name || "").replace(/\.usdz$/i, "");

      const candidateModelPaths = [
        model.modelPath,
        normalizedName ? `models/${normalizedName}.usdz` : null,
      ].filter(Boolean);

      const candidateThumbnailPaths = [
        model.thumbnailPath,
        normalizedName ? `thumbnails/${normalizedName}.jpg` : null,
      ].filter(Boolean);

      const deleteStoragePath = async (path) => {
        try {
          await deleteObject(ref(storage, path));
        } catch (error) {
          // Ignore missing files so cleanup can continue.
          if (error?.code !== "storage/object-not-found") {
            throw error;
          }
        }
      };

      // Delete the uploaded files first, then remove the DB record.
      await Promise.all([
        ...candidateModelPaths.map(deleteStoragePath),
        ...candidateThumbnailPaths.map(deleteStoragePath),
      ]);

      await deleteDoc(doc(db, "models", model.id));
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
              
              {/* image upload */}
            <div>
              <label className="block text-sm font-medium mb-1">
                Thumbnail Image
              </label>
              <input
                type="file"
                accept="image/*"
                onChange={(e) => {
                  const file = e.target.files?.[0] || null;

                  if (file && !file.type.startsWith("image/")) {
                    alert("Please upload a valid image.");
                    return;
                  }

                  setThumbnail(file);
                }}
                className="w-full border border-border rounded px-3 py-2"
              />

              {thumbnail && (
                <p className="text-sm mt-2">
                  Thumbnail: {thumbnail.name}
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