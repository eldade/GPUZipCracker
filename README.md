##  GPUZipCracker
*A fast GPU-based password brute-forcing tool for ZIP archives (for macOS)*

Years ago, when I wanted to store files with a reasonable amount of security/privacy, I used to use encrypted ZIP archives to store files. The problem was that ZIP archives don't actually encrypt their directory, so the metadata was stored in plaintext. If you wanted to hide filenames, folder names, etc., you had to first put everything into one ZIP archive, then store that single archive into another, encrypted ZIP file.

Unsurprisingly, after over 15 years many of the passwords to those archives are now long forgotten, and so cracking them somehow became interesting.

These ZIP archives were stored using the original ZIP encryption method, often referred to as the 'traditional PKWARE encryption'. This was a fairly primitive, 96-bit encryption scheme that has been broken in a number of different ways, though most of these techniques seem to require at least 12-14 bytes of known plaintext (which seems difficult to get with these ZIP archives I stored inside the encrypted ZIP archive).

>NOTE: Modern ZIP archives are encrypted using a stronger, AES-based encryption cipher (which is not supported by this program) that utilizes proper password hashing based on PBKDF2, and will therefore be significantly slower to brute-force. This program does not support such archives.

In my recent Metal API studies, I was curious to see if the GPU could offer a meaningful performance advantage if one wanted to simply bruteforce the password of such an archive. For bruteforcing, you would normally have to decrypt the entire file in order to actually confirm that you have the correct password. In such a scenario, bruteforcing is going to be very expensive since each password permutation will require millions of operations.

Luckily, since in this case the encrypted file is in itself another ZIP archive, we know the 4-byte file header. So we effectively have 4 bytes of plaintext at the very beginning of the encrypted stream.

This means that for each bruteforcing iteration we need to do the following:
1. Generate a password based on the current iterator value and a given characterset (uppercase, lowercase, symbols, etc.)
2. Hash that password into a 96-bit decryption key
3. Decrypt the 11 salt bytes traditional ZIP encryption uses to ensure randomness, plus the 12th byte which is used as a quick password check. That 12th byte is either a byte from the file's CRC or from the file's modified date. Either way, it is available to us as a quick way to rule out most passwords.
4. Decrypt the first 4 bytes of the encrypted files
5. Now we have a total of 5 decrypted bytes we can compare against known plaintext bytes.
6. If that test passes, the GPU returns the index of the password that generated it, and we do an actual full decryption to verify the password is correct (because in some cases we will run **trillions** of tests, this might actually happen numerous times during a lenghty run).

> Note: The current version **only** supports decrypting 'stored' ZIP archives within ZIP archives (meaning a ZIP archive stored -- not compressed -- within another ZIP archive). It should be very easy to add additional file formats by setting up a table that uses the extension of the file within the ZIP archive, and having some hardcoded plaintext header bytes for each file format. How many known bytes of header do we need? Since we already have one known plaintext byte from the ZIP encryption header, I'd say the minimum is probably 2-3 bytes.
> At 2 known header bytes plus the extra known byte, the GPU would trigger a false-positive roughly once every 2^24 attempts (about 16M), which would actually be pretty frequent and might significantly reduce performance.

## Performance

The program uses a Metal-API based compute shader to bruteforce the password. It is set up to simultaneously utilize all available GPUs on a given system, but you can pick a single GPU from the command line if you wish.
Real-world performance seems to be at least 1-2 orders of magnitude faster than what you can expect with a nice Intel CPU. I've tested this on several Macs and performance was very promising.

For example, on a 2013 Mac Pro, the program was able to test approximately 1.6 billion hashes per second. The same machine was only able to achieve approximately 28 million permutations per second when running on all 8 cores of that same system.

On a 2017 15" MacBook Pro, the program was able to test approximately 550 million hashes per second (running concurrently on both the Intel *and* AMD GPUs).

## Usage
To try it out, download the code, build the program using Xcode, and launch it with the provided test file:
`./GPUZipCracker -i test.zip -c abcdefghijklmnopqrstuvwxyz`

Runtime using these settings and the provided file should be anywhere from 10-30 minutes, depending on your system's GPU. Note that the program will likely estimate several days of runtime remaining because it is programmed to try everything up to 10 character passwords, which can take a while.

The program actually supports several command-line options including selecting which GPU to use, specifying a character set, minimum and maximum word lengths, and even starting from a specific word if 'lower' words have already been eliminated (meaning, words lower in the alphabet for the specified character set).

## Alternatives
This is not intended as a professional password cracking tool by any means. It is a proof of concept I developed while learning the Metal API. If you're looking for a high-performance GPU-accelerated password bruteforcing tool, take a look at [hashcat](https://github.com/hashcat/hashcat).

## Credits
Portions of this code were based on [**BoboTiG/cracker-ng**](https://github.com/BoboTiG/cracker-ng), which is an excellent resource for ZIP cracking/bruteforcing. That program is entirely CPU-based and does not seem to utilize any kind of plaintext trickery as far as I can tell, therefore it is several orders of magnitude slower than GPUZipCracker, but is is far more flexible in the types of archives it is able to handle.
