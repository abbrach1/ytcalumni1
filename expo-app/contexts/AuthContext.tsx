import React, { createContext, useContext, useEffect, useState } from 'react';
import { auth, checkUserApproval, onAuthStateChanged, User } from '../services/firebase';
import { signOut as firebaseSignOut } from 'firebase/auth';

interface AuthState {
  user: User | null;
  isApproved: boolean;
  isAdmin: boolean;
  isLoading: boolean;
}

interface AuthContextValue extends AuthState {
  signOut: () => Promise<void>;
  refreshStatus: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  isApproved: false,
  isAdmin: false,
  isLoading: true,
  signOut: async () => {},
  refreshStatus: async () => {},
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null,
    isApproved: false,
    isAdmin: false,
    isLoading: true,
  });

  const checkAndSetApproval = async (user: User) => {
    if (!user.email) return;
    const { approved, admin } = await checkUserApproval(user.email);
    setState((prev) => ({
      ...prev,
      user,
      isApproved: approved,
      isAdmin: admin,
      isLoading: false,
    }));
  };

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        await checkAndSetApproval(user);
      } else {
        setState({ user: null, isApproved: false, isAdmin: false, isLoading: false });
      }
    });
    return unsubscribe;
  }, []);

  const signOut = async () => {
    await firebaseSignOut(auth);
  };

  const refreshStatus = async () => {
    if (state.user) {
      await checkAndSetApproval(state.user);
    }
  };

  return (
    <AuthContext.Provider value={{ ...state, signOut, refreshStatus }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
