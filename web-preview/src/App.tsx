import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import ErrorBoundary from "./components/ErrorBoundary";
import { ThemeProvider } from "./contexts/ThemeContext";
import { AppProvider, useApp } from "./contexts/AppContext";
import Home from "./pages/Home";

function AppContent() {
  return (
    <div className="min-h-screen bg-[#0a0a14] flex items-center justify-center p-4">
      {/* Phone Frame */}
      <div className="phone-frame">
        <div className="phone-notch" />
        <div className="phone-content">
          <Home />
        </div>
      </div>
    </div>
  );
}

function App() {
  return (
    <ErrorBoundary>
      <ThemeProvider defaultTheme="dark">
        <TooltipProvider>
          <Toaster />
          <AppProvider>
            <AppContent />
          </AppProvider>
        </TooltipProvider>
      </ThemeProvider>
    </ErrorBoundary>
  );
}

export default App;
