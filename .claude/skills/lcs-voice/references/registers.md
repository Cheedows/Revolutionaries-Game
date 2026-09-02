# The seven registers

Every exemplar below is the original's own words. Leading spaces are real —
that is where the engine injects a name. Where the original builds a line out
of consecutive `addstr()` calls, it is shown here as the player reads it rather
than as one literal, so grep for a phrase from it rather than the whole line.
`scripts/find_original.py` does that for you.

Contents: [News](#1-news) · [Action](#2-action-combat-chase-siege) ·
[Dialogue](#3-dialogue) · [Interrogation](#4-interrogation-and-dating) ·
[Activity report](#5-the-daily-activity-report) · [Menus](#6-menus-labels-and-prompts) ·
[Endgame](#7-endgame-and-ceremony)

---

## 1. News

The longest form in the game and the one with the most rules. A story is
assembled from consecutive `strcat()` calls into one buffer, so it reads as
continuous prose with `&r` for paragraph breaks.

**Shape.** `<CITY> - ` then the lede in one sentence. Then who, in full name,
doing something ordinary when the thing happened. Then the numbers. Then a
paragraph break and the witness account. Then a paragraph break and the
family, the poll, or the official statement.

```
Seattle - A doctor that routinely performed illegal abortion-murders was
ruthlessly gunned down outside of the Halvorsen Clinic yesterday.  Dr. Mia
Reyes was walking to her car when, according to police reports, shots were
fired from a nearby vehicle.  Reyes was hit 9 times and died immediately in
the parking lot.  The suspected shooter, Dale Ackerman, is in custody.&r
  Witnesses report that Ackerman remained at the scene after the shooting,
screaming verses of the Bible at the stunned onlookers.  Someone called the
police on a cellphone and they arrived shortly thereafter.  Ackerman
surrendered without a struggle, reportedly saying that God's work had been
completed.&r
  Reyes is survived by her husband and three children.
```

*(Reconstructed from what `VIEW_WOMEN` in `src/news/majorevent.cpp` assembles —
the names and the count are generated, so no two printings match. Don't grep
for it; grep for its pieces.)*

**Register rules specific to news**

- Attribution is constant and bureaucratic: *according to police reports*,
  *according to a spokesperson from the police department*, *sources say*,
  *reports indicate*, *a poll completed yesterday*.
- The paper is never certain. *allegedly*, *is believed to have*, *what
  appeared to be*, *Details about injuries were not released.*
- Two spaces between sentences. Paragraphs open with two spaces after `&r`.
- Numbers are exact and unremarkable: *hit 9 times*, *Over thirty companies*,
  *more than one thousand pages*, *twenty-five members of Congress*.
- Quotations from officials are self-incriminating and delivered flat:
  *"While we understand your concerns, any worries are entirely unfounded.  I
  think the media should be focusing on the enormous benefits of this drug."*
- The satire is in which adjective the law selects. Never in the reporter's
  tone.

**The paper's own voice shifts with who owns it.** The Liberal Guardian is
earnest and slightly overheated: *This is clearly the work of conservative
butchers enforcing the prohibition on a free press.* The Conservative press is
smug: *They have to be stopped before they kill again.* Same events.

**Television** is three lines in a box, centred, present tense, no attribution:

```
      The  police  have  beaten  a  black  man  in
    Los Angeles again.  This time, the incident is
    taped by  a passerby  and saturates  the news.
```

---

## 2. Action (combat, chase, siege)

Short, present tense, exclamation marks, no interiority. The unit of writing is
one clause.

```
" spins and blocks the attack!"        " fakes a right, and goes left instead!"
" squeezes between some bridge supports for cover!"
" cuts off another driver and the shot is blocked!"
" power slides through a narrow gap in the traffic!"
" just barely missed!"                 " wisely stays behind cover!"
" confidently allows the attack to miss!"
"The attack bounces off "              " is immune to the attack!"
```

Dodges are graded, and the grade is the joke: from *notices at the last
moment!* through *nimbly dodges away from the line of fire!* to *seems to avoid
the attack with only an angry glare!* Write the whole ladder, not the middle.

Wounds are anatomical and unadorned:

```
"'s right eye is blasted out!"    "'s upper spine is shattered!"
"'s left lung is punctured!"      "'s nose is cut off!"
"'s tongue is torn out!"
```

Deaths are quiet:

```
" silently drifts away, and is gone."
" sweats profusely, murmurs something about Jesus, and dies."
" crawls off moaning..."
```

Siege prose is the one place the game addresses the player directly, in the
register of a briefing:

```
"You have received advance warning from your sleepers regarding "
"An M1 Abrams Tank takes up position outside the compound."
"Unmarked black vans are surrounding the "
"You hear planes streak overhead!"
"There's nothing left but smoking wreckage..."
"Army engineers have removed your tank traps."
```

---

## 3. Dialogue

Always in double quotes, one line, spoken as people actually speak — clipped,
rude, unliterary. No dialogue tags, ever; the surrounding line supplies who.

```
"Jesus... it's yours..."
"I don't sell guns, officer."
"Uhhh... not a good place for this."
"I think you'd better leave."
"You're gonna stir up the hornet's nest, fool."
"Real men fight with fists. And no, you can't come in."
"Blood?! That's more than a little suspicious..."
"That looks like you sewed it yourself."
```

Refusals at a door are personal and specific — sixty-odd of them, each about
one thing that is wrong with you. Not one summary line.

Chat-up lines are deliberately terrible and the game commits completely:

```
"Did it hurt when you fell from heaven?"
"I lost my phone number.  Could I have yours?"
"Your parents must be retarded, because you are special."
"If you were a phaser, you'd be set on 'stunning'."
```

Replies match the register of the line they answer: *"He he, I'll let that one
slide.  Besides, I like country folk..."*

Bracketed dialogue `"[I go to your church.]"` marks something the speaker is
performing rather than meaning — a disguise or a lie.

---

## 4. Interrogation and dating

The bleakest register, and it works by being administrative about atrocity.
The plan is a menu; the outcome is a sentence.

```
A - Attempt to Convert
B - Physical Restraints
C - Violently Beaten
D - Expensive Props     ($250)
E - Hallucinogenic Drugs    ($50)

K - Kill the Hostage

Press Enter to Confirm the Plan
```

The unchosen options read `No Verbal Contact`, `No Physical Restraints`, `Not
Violently Beaten`, `No Expensive Props` — the screen states what you are not
doing to it as flatly as what you are.

Then:

```
" reenacts scenes from Abu Ghraib"
" pushes needles under the Automaton's fingernails"
"It is subjected to dangerous hallucinogens."
" wonders about apples."
" takes solace in the personal appearance of God."
" begs for the nightmare to end."
" will never be broken so long as God grants it strength."
" has committed suicide."
"Unfortunately, none of it is useful to the LCS."
"Press any key to reflect on this."
```

Note the pronoun: a captured Conservative is **it**. That is the game's point
about what the squad is doing, made without a word of comment. Keep it.

Dating is the same machine pointed at romance:

```
" is quite taken with "
"'s frozen Conservative heart."
"They'll meet again tomorrow."
" spends the night getting drunk alone."
" makes like a tree and leaves."
"This relationship is over."
"Unfortunately, they all turn up at the same time."
```

---

## 5. The daily activity report

One line per person per day. Fragment, verb-first, faintly absurd, no stakes
announced.

```
" peruses some sewing magazines."
" cannot afford material for clothing."
" works through the night on a large mural."
" was nearly caught in a prostitution sting."
" is cornered by a mob of angry rednecks."
" looks around for an accessible vehicle..."
" fiddles with the lock with no luck."
" has been spotted by a passerby!"
" sees a police car driving around a few blocks away."
"posted horrifying dead abortion doctor pictures downtown!"
"dressed up and pretended to be a radioactive mutant!"
```

Public opinion reports are past tense and statistical:

```
"were terrified of nuclear power"
"would boycott companies that used sweatshops"
"respected the power of the Liberal Crime Squad"
"The public is not concerned with politics right now."
```

---

## 6. Menus, labels and prompts

Title Case, a key letter, an em-free hyphen separator, price in brackets.

```
"R - Remove member"                 "K - Kill member"
"W - Wait a day"                    "Press Z to Assemble a New Squad."
"E - Equip Squad"                   "L - The Status of the Liberal Agenda"
"P - PATRIOTISM: fly a flag here ($20)"
"S - FREE SPEECH: the Liberal Slogan"
"A - Install a perfectly legal Anti-Aircraft gun on the roof ($35,000)"
"Press a Letter to View Status."
"Enter - Done"
```

Column headers shout: `CODE NAME`, `SKILL`, `HEALTH`, `LOCATION`, `SQUAD /
ACTIVITY`, `DAYS IN CAPTIVITY`, `MONTHS LEFT`, `DIFFICULTY TO ARRANGE MEETING`.

Setup screens are whole sentences asked as questions: *In what world will you
pursue your Liberal Agenda?* *What type of person will Marcus try to meet and
recruit today?* *Which hostage will Ida be watching over?*

Options are characterised rather than described — the difficulty menu reads
*Fast skills - Grinding is Conservative!*, *Classic - Excellence requires
practice.*, *Hard Mode - Learn from the best, or face arrest!* Never *Easy /
Normal / Hard*.

Warnings are two flat lines and a confirm key:

```
"Do you want to permanently release this squad member from the LCS?"
"If the member has low heart they may go to the police."
"  C - Confirm       Any other key to continue"
```

---

## 7. Endgame and ceremony

The only register that rises, and it rises into legalese and small caps
because a constitution is being rewritten:

```
"The Elite Liberal Congress is proposing an ELITE LIBERAL AMENDMENT!"
"the pressure of the elite liberal threat, WE THE PEOPLE HEREBY"
"boundaries to be determined by leading theologians."
"People may petition Jesus for a redress of grievances, as"
"Minister of Love Strom Thurmond, Minister of Peace Jesse Helms,"
"Press any key to reflect on what has happened ONE LAST TIME."
```

Defeat is three words and a shrug: *"They'll round up the last of you
eventually.  All is lost."* / *"Ain't no sunshine..."*

High scores are a single clause per ending, all built on one frame:

```
"The Liberal Crime Squad liberalized the country in "
"The Liberal Crime Squad was brought to justice in "
"The Liberal Crime Squad was out-Crime Squadded in "
"The country was Reaganified in "
```

Sixteen of them. When you add an ending, write it into that frame.

The title screen carries thirty-two real quotations about disobeying the law —
Thoreau, King, Zinn, Douglass. They are the only words in the game not about
the game, and they are quoted exactly. Do not paraphrase a source and do not
invent one.
