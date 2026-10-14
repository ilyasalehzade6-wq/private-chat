// js/auth.js
import { supabase } from './supabase-client.js';

export async function signUp({ email, password, username, displayName }) {
  const { data, error } = await supabase.auth.signUp({
    email, password,
    options: { data: { username: username.toLowerCase().trim(), display_name: displayName || username } }
  });
  return { data, error };
}

export async function signIn(email, password) {
  return await supabase.auth.signInWithPassword({ email, password });
}

export async function signOut() {
  await supabase.auth.signOut();
}

export async function getCurrentUser() {
  const { data: { user } } = await supabase.auth.getUser();
  return user;
}

export async function getProfile(userId) {
  return await supabase.from('profiles').select('*').eq('id', userId).single();
}

export async function requireAuth() {
  const user = await getCurrentUser();
  if (!user) { window.location.href = './index.html'; return null; }
  return user;
}

export async function redirectIfLoggedIn() {
  const user = await getCurrentUser();
  if (user) window.location.href = './chat.html';
}
