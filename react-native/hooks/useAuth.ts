import { useState, useEffect, createContext, useContext } from 'react';
import { User } from 'firebase/auth';
import {
  AuthState,
  UserProfile,
  checkUserApproval,
  signIn,
  signUp,
  signOutUser,
  onAuthChange,
} from '../managers/AuthManager';

const initialState: AuthState = {
  user: null,
  isApproved: false,
  isAdmin: false,
  isLoading: true,
  userProfile: null,
  errorMessage: null,
};

export function useAuthProvider() {
  const [state, setState] = useState<AuthState>(initialState);

  useEffect(() => {
    const unsubscribe = onAuthChange(async (user) => {
      if (user && user.email) {
        const { isApproved, isAdmin } = await checkUserApproval(user.email);
        setState({
          user,
          isApproved,
          isAdmin,
          isLoading: false,
          userProfile: {
            id: user.uid,
            email: user.email.toLowerCase(),
            firstName: '',
            lastName: '',
            isApproved,
            isAdmin,
          },
          errorMessage: null,
        });
      } else {
        setState({
          ...initialState,
          isLoading: false,
        });
      }
    });

    return unsubscribe;
  }, []);

  const handleSignIn = async (email: string, password: string) => {
    setState((s) => ({ ...s, isLoading: true, errorMessage: null }));
    try {
      const result = await signIn(email, password);
      setState((s) => ({
        ...s,
        user: result.user,
        isApproved: result.isApproved,
        isAdmin: result.isAdmin,
        isLoading: false,
        userProfile: {
          id: result.user.uid,
          email: email.toLowerCase(),
          firstName: '',
          lastName: '',
          isApproved: result.isApproved,
          isAdmin: result.isAdmin,
        },
      }));
      return result;
    } catch (error: any) {
      setState((s) => ({
        ...s,
        isLoading: false,
        errorMessage: error.message || 'Sign in failed',
      }));
      throw error;
    }
  };

  const handleSignUp = async (
    email: string,
    password: string,
    firstName: string,
    lastName: string
  ) => {
    setState((s) => ({ ...s, isLoading: true, errorMessage: null }));
    try {
      const result = await signUp(email, password, firstName, lastName);
      setState((s) => ({
        ...s,
        user: result.user,
        isApproved: result.isApproved,
        isAdmin: result.isAdmin,
        isLoading: false,
        userProfile: {
          id: result.user.uid,
          email: email.toLowerCase(),
          firstName,
          lastName,
          isApproved: result.isApproved,
          isAdmin: result.isAdmin,
        },
      }));
      return result;
    } catch (error: any) {
      setState((s) => ({
        ...s,
        isLoading: false,
        errorMessage: error.message || 'Sign up failed',
      }));
      throw error;
    }
  };

  const handleSignOut = async () => {
    await signOutUser();
    setState({ ...initialState, isLoading: false });
  };

  const refreshStatus = async () => {
    if (state.user?.email) {
      const { isApproved, isAdmin } = await checkUserApproval(state.user.email);
      setState((s) => ({ ...s, isApproved, isAdmin }));
    }
  };

  return {
    ...state,
    signIn: handleSignIn,
    signUp: handleSignUp,
    signOut: handleSignOut,
    refreshStatus,
  };
}

export type AuthContextType = ReturnType<typeof useAuthProvider>;

export const AuthContext = createContext<AuthContextType | null>(null);

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
}
