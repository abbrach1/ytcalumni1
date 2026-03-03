import { Redirect } from 'expo-router';
import { useAuth } from '../hooks/useAuth';

export default function Index() {
  const { user, isApproved } = useAuth();

  if (!user) return <Redirect href="/auth" />;
  if (!isApproved) return <Redirect href="/pending" />;
  return <Redirect href="/(tabs)" />;
}
