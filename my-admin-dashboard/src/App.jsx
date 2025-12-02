import { Routes, Route } from "react-router-dom";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import ScenesList from "./pages/ScenesList";
import ScenePage from "./pages/ScenePage";

function App() {
  return (
    <Routes>
      <Route path="/" element={<Login />} />

      {/* Dashboard layout wrapper */}
      <Route path="/dashboard/*" element={<Dashboard />}>
        {/* Nested routes inside Dashboard */}
        <Route path="scenes" element={<ScenesList />} />
        <Route path="scene/:id" element={<ScenePage />} />
      </Route>

      {/* Fallback for unknown routes */}
      <Route path="*" element={<div className="p-6 text-red-600 font-bold">404: Page Not Found</div>} />
    </Routes>
  );
}

export default App;
