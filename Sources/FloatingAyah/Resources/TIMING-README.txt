quran-align timing file package
===============================

https://github.com/cpfair/quran-align

License
-------

These data files are licensed under a [Creative Commons Attribution 4.0
International License](https://creativecommons.org/licenses/by/4.0/). Please
consider emailing me if you use this data, so I can let you know when new &
revised timing data is available.

Contents
--------

* Abdul_Basit_Mujawwad_128kbps.json
  24 November 2016
  d0c5d63917c0a2d59f0d86ce27936251b6d76f90
* Abdul_Basit_Murattal_64kbps.json
  24 November 2016
  029e32d2cdc869e2f33ae86fd21214952d18f33d
* Abdurrahmaan_As-Sudais_192kbps.json
  24 November 2016
  4315194bc88db14192201426fb4f6617bffac4ac
* Abu_Bakr_Ash-Shaatree_128kbps.json
  24 November 2016
  8861fadb68bad84ae5189227e0bcdd7a7127e976
* Alafasy_128kbps.json
  24 November 2016
  167bfc53255152aaf8c9a2e5e79c1160134c77a4
* Hani_Rifai_192kbps.json
  24 November 2016
  22e0cea40ff434848295f8ce959ab885292ebb7b
* Husary_64kbps.json
  24 November 2016
  8e7a24f66f98f176dfddf65b434643a6655c694d
* Husary_Muallim_128kbps.json
  24 November 2016
  b03e6c9188934504b6921d22b1f2e2b72ee773eb
* Minshawy_Mujawwad_192kbps.json
  24 November 2016
  da6c3850917c6e104e650a07542a6c7341539af5
* Minshawy_Murattal_128kbps.json
  24 November 2016
  2a24d42e7f3a018c56600fc4ddd580f214b20a39
* Mohammad_al_Tablaway_128kbps.json
  24 November 2016
  dce92289eebd76380d1dae22f2329493a49f06db
* Saood_ash-Shuraym_128kbps.json
  24 November 2016
  59fd80d144caa6fe79a917a8d1dddf18087b3bcc

Format
------
Data files are JSON, of the following format:

    [
        {
            "surah": 1,
            "ayah": 1,
            "segments": {
                [word_start_index, word_end_index, start_msec, end_msec],
                ...
            },
            "stats": {
              "insertions": 123,
              "deletions": 456,
              "transpositions": 789
            }
        },
        ...
    ]

Where...

* `word_start_index` is the 0-base index of the first word contained in the
segment.
* `word_end_index` is the 0-base index of the word _after_ the last word
contained in the segment.
* `start_msec`/`end_msec` are timestamps within the input audio file.
* `stats` contain statistics from the matching routine that aligns the
recognized words with reference text.

Here, a "word" is defined by splitting the text of the Qur'an  by spaces
(specifically, `quran-uthmani.txt` from [Tanzil.net](http://tanzil.net/download)
- without me_quran tanween differentiation!). Note that the language model used
for recognition treats muqata'at as sets of words (ا ل م instead of الم) -
but they will appear as a single word in the alignment output.

