a() {
  echo 'a'
  return 0;
}

b() {
  echo 'b'
  return 0;
}

a && b && echo 'gogo'
