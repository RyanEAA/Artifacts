import { Routes, Route } from "react-router-dom";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Users from "./pages/Users";
import Artifacts from "./pages/Artifacts";
import Unauthorized from "./pages/Unauthorized";
import ProtectedRoute from "./routes/ProtectedRoute";
import Models from "./pages/Models";

export default function App() {
  return (
    <Routes>
      {/* Public */}
      <Route path="/" element={<Login />} />

      {/* Admin-only dashboard */}
      <Route
        path="/dashboard"
        element={
          <ProtectedRoute adminOnly>
            <Dashboard />
          </ProtectedRoute>
        }
      />

      {/* Admin-only users page */}
      <Route
        path="/dashboard/users"
        element={
          <ProtectedRoute adminOnly>
            <Users />
          </ProtectedRoute>
        }
      />

      {/* Future admin-only routes */}
      
      <Route
        path="/dashboard/artifacts"
        element={
          <ProtectedRoute adminOnly>
            <Artifacts />
          </ProtectedRoute>
        }
      />
      <Route
        path="/dashboard/models"
        element={
          <ProtectedRoute adminOnly>
            <Models />
          </ProtectedRoute>
        }
      />
     

      {/* Unauthorized */}
      <Route path="/unauthorized" element={<Unauthorized />} />

      {/* 404 */}
      <Route
        path="*"
        element={
          <div className="p-6 text-red-600 font-bold">
            404: Page Not Found
          </div>
        }
      />
    </Routes>
  );
}
