import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { ThemeProvider } from "./contexts/ThemeContext";
import { AuthProvider, useAuth } from "./contexts/AuthContext";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Unauthorized from "./pages/Unauthorized";

function AppContent() {
  const { auth } = useAuth();

  if (auth.status === "loading") {
    return (
      <div className="min-h-screen bg-[#111214] flex items-center justify-center">
        <div className="w-6 h-6 border-2 border-[#E040FB] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (auth.status === "unauthenticated") {
    return <Login />;
  }

  if (auth.status === "not_team_member") {
    return <Unauthorized />;
  }

  return <Dashboard />;
}

function App() {
  return (
    <ThemeProvider defaultTheme="dark">
      <AuthProvider>
        <TooltipProvider>
          <Toaster
            theme="dark"
            toastOptions={{
              style: {
                background: "#1C1E22",
                border: "1px solid #2A2D34",
                color: "#E8E8E8",
              },
            }}
          />
          <AppContent />
        </TooltipProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;
