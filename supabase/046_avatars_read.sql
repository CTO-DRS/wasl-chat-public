-- 046: سياسة قراءة لسلّة الصور الشخصية والأغلفة
-- رفع الصورة بـ upsert يحتاج SELECT على storage.objects وإلا يفشل التحديث
-- (سبب فشل تغيير الصورة/الغلاف). السلّة عامة أصلاً للعرض، فالقراءة آمنة.
drop policy if exists "avatars read" on storage.objects;
create policy "avatars read" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');
