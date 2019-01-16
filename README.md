# bitlocker-tool
A command-line tool for enabling BitLocker and storing the generated keys based on date and machine serial number.

This is pretty self explainatory I feel, so here's some history instead:

This tool was created for a production environment in which several hundreds of Windows OS devices needed to be encrypted with BitLocker,
and the resulting keys stored and recorded. The original tool was quickly made to work with the specific production environment in mind, 
and resulted in some fast-and-loose code that I'd like to refine if possible. I'd also like to create a more general public-use version,
that is why this repo exists...for the most part.
