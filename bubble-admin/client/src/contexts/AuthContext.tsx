import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from "react";
import { Session, User } from "@supabase/supabase-js";
import { supabase, Profile } from "@/lib/supabase";

type AuthState =
  | { status: "loading" }
  | { status: "unauthenticated" }
  | { status: "not_team_member"; user: User }
  | { status: "authenticated"; user: User; profile: Profile; session: Session };

const AuthContext = createContext<{
  auth: AuthState;
  signIn: (email: string, password: string) => Promise<string | null>;
  signOut: () => Promise<void>;
}>({
  auth: { status: "loading" },
  signIn: async () => null,
  signOut: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>({ status: "loading" });

  async function loadProfile(user: User, session: Session) {
    const { data, error } = await supabase
      .from("profiles")
      .select("id, nickname, icon_url, is_team_admin, is_team_moderator")
      .eq("id", user.id)
      .single();

    if (error || !data) {
      setAuth({ status: "not_team_member", user });
      return;
    }

    const profile = data as Profile;
    if (!profile.is_team_admin && !profile.is_team_moderator) {
      setAuth({ status: "not_team_member", user });
      return;
    }

    setAuth({ status: "authenticated", user, profile, session });
  }

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session) {
        setAuth({ status: "unauthenticated" });
        return;
      }
      loadProfile(session.user, session);
    });

    const { data: listener } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        if (!session) {
          setAuth({ status: "unauthenticated" });
          return;
        }
        loadProfile(session.user, session);
      }
    );

    return () => listener.subscription.unsubscribe();
  }, []);

  async function signIn(email: string, password: string): Promise<string | null> {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return error.message;
    return null;
  }

  async function signOut() {
    await supabase.auth.signOut();
  }

  return (
    <AuthContext.Provider value={{ auth, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
