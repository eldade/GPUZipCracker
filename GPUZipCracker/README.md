#  GPUZipCracker
## A fast GPU-based password brute-forcing tool for ZIP archives (for macOS)

Years ago, when I wanted to store files with a reasonable amount of security/privacy, I used to use encrypted ZIP archives to store files. The problem was that ZIP archives don't actually encrypt their directory, so that metadata was store in plaintext. If you wanted to hide filenames, folder names, etc., you had to first put everything into one ZIP archive, then store that single archive into another, encrypted ZIP file.

Recently I found a bunch of such old archives where the password has been long lost. 

