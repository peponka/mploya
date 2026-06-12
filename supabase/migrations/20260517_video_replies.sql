-- ──────────────────────────────────────────────────────────────────────────────
-- Migration: Add video_replies storage support
-- Date: 2026-05-17
-- Description: Update the storage INSERT policy to also allow video_replies/ path
-- ──────────────────────────────────────────────────────────────────────────────

-- Update the existing policy to include video_replies path
-- Run this in Supabase SQL Editor:

DROP POLICY IF EXISTS "Users can upload own videos" ON storage.objects;

CREATE POLICY "Users can upload own videos" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'videos'
    AND auth.uid() IS NOT NULL
  );

-- This allows authenticated users to upload to any path in the 'videos' bucket,
-- including: pitches/, nexus/, avatars/, stories/, video_replies/
