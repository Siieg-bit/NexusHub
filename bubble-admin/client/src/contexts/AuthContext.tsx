import {
  createContext,
  useContext,
  useEffect,
  useState,
  ReactNode,
} from "react";
import { Session, User } from "@supabase/supabase-js";
import { supabase, Profile, TeamRole, getTeamRoleRank } from "@/lib/supabase";

type AuthState =
  | { status: "loading" }
  | { status: "unauthenticated" }
  | { status: "not_team_member"; user: User }
  | { status: "authenticated"; user: User; profile: Profile; session: Session };

interface AuthContextValue {
  auth: AuthState;
  signIn: (email: string, password: string) => Promise<string | null>;
  signOut: () => Promise<void>;
  isFounder: boolean;
  isCoFounderOrAbove: boolean;
  canManageTeamRoles: boolean;
  canModerate: boolean;
  teamRole: TeamRole;
  teamRank: number;
}

const AuthContext = createContext<AuthContextValue>({
  auth: { status: "loading" },
  signIn: async () => null,
  signOut: async () => {},
  isFounder: false,
  isCoFounderOrAbove: false,
  canManageTeamRoles: false,
  canModerate: false,
  teamRole: null,
  teamRank: 0,
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [auth, setAuth] = useState<AuthState>({ status: "loading" });

  async function loadProfile(user: User, session: Session) {
    const { data, error } = await supabase
      .from("profiles")
      .select("id, nickname, icon_url, is_team_admin, is_team_moderator, team_role, team_rank, amino_id")
      .eq("id", user.id)
      .single();

    if (error || !data) {
      setAuth({ status: "not_team_member", user });
      return;
    }

    const profile = data as Profile;
    const isTeamMember =
      profile.is_team_admin ||
      profile.is_team_moderator ||
      (profile.team_rank != null && profile.team_rank > 0);

    if (!isTeamMember) {
      setAuth({ status: "not_team_member", user });
      return;
    }

    setAuth({ status: "authenticated", user, profile, session });
  }

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session) { setAuth({ status: "unauthenticated" }); return; }
      loadProfile(session.user, session);
    });
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (!session) { setAuth({ status: "unauthenticated" }); return; }
      loadProfile(session.user, session);
    });
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

  const profile = auth.status === "authenticated" ? auth.profile : null;
  const teamRole: TeamRole = profile?.team_role ?? null;
  const teamRank: number = profile?.team_rank ?? 0;
  const isFounder = teamRole === "founder";
  const isCoFounderOrAbove = teamRank >= 90;
  const canManageTeamRoles = teamRank >= 80;
  const canModerate = teamRank >= 70 || (profile?.is_team_moderator ?? false);

  return (
    <AuthContext.Provider value={{ auth, signIn, signOut, isFounder, isCoFounderOrAbove, canManageTeamRoles, canModerate, teamRole, teamRank }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
