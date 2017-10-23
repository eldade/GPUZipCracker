#  GPUZipCracker
## A fast GPU-based password brute-forcing tool for ZIP archives (for macOS)

Years ago, when I wanted to store files with a reasonable amount of security/privacy, I used to use encrypted ZIP archives to store files. The problem was that ZIP archives don't actually encrypt their directory, so that metadata was store in plaintext. If you wanted to hide filenames, folder names, etc., you had to first put everything into one ZIP archive, then store that single archive into another, encrypted ZIP file.

These ZIP archives were stored using the original ZIP encryption method, often referred to as the 'traditional PKWARE encryption'. This was a fairly primitive, 96-bit encryption system that has been broken in a number of different ways, though most of these techniques seem to require at least 12-14 bytes of known plaintext.

In my Metal API studie, I was curious to see if the GPU offered any meaningful performance advantage if one wanted to simply bruteforce 
