-- Allow authenticated users to INSERT objects only under their users/{uid}/ prefix
CREATE POLICY "images_insert_owner_path" ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images'
  AND left(name, char_length('users/' || auth.uid() || '/')) = 'users/' || auth.uid() || '/'
);

-- Allow authenticated users to UPDATE objects only under their users/{uid}/ prefix
CREATE POLICY "images_update_owner_path" ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'images'
  AND left(name, char_length('users/' || auth.uid() || '/')) = 'users/' || auth.uid() || '/'
)
WITH CHECK (
  bucket_id = 'images'
  AND left(name, char_length('users/' || auth.uid() || '/')) = 'users/' || auth.uid() || '/'
);

-- Allow authenticated users to DELETE objects only under their users/{uid}/ prefix
CREATE POLICY "images_delete_owner_path" ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images'
  AND left(name, char_length('users/' || auth.uid() || '/')) = 'users/' || auth.uid() || '/'
);
