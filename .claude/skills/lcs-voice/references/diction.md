# Diction: the words the game already owns

Read this when you are naming something, or when a word choice depends on game
state. Everything here is verbatim from `src/` or `art/*.xml`.

Contents: [Lexicon](#the-fixed-lexicon) · [State-driven vocabulary](#vocabulary-that-changes-with-the-law) ·
[Censorship tiers](#the-censorship-tiers) · [Charges](#charges) ·
[Health words](#health-in-one-word) · [Ranks](#ranks) ·
[Activity names](#activity-names) · [Naming things](#naming-new-things)

---

## The fixed lexicon

These are terms of art. Using a synonym is a departure, not a style choice.

| word | means | not |
|---|---|---|
| **Liberal** | a member, or the faction | activist, rebel, radical |
| **Conservative** | an enemy, or the faction | enemy, hostile, opponent |
| **Elite Liberal** | the top of the scale, and the win condition | maxed, perfect |
| **Automaton** | a captured Conservative, referred to as **it** | prisoner, captive |
| **Enlightened** | converted by interrogation | recruited, turned, brainwashed |
| **Juice** | personal standing | reputation, XP, renown |
| **Martyr** | a dead member | casualty, loss, KIA |
| **the Squad** | the active party | the party, the team |
| **sleeper** | an embedded agent | spy, mole, informant |
| **safehouse** / **the Shelter** | the base | HQ, hideout |
| **the Liberal Guardian** | the squad's paper | the newspaper |
| **the Conservative Crime Squad / CCS** | the rival | the enemy faction |
| **Not a Liberal Act** | the game's moral verdict, always this exact phrase | wrong, immoral |
| **Public Opinion** / **the Issues** | the political sim | reputation, influence |
| **Heat** | police attention on a person | suspicion, notoriety |

Institutions have proper names and Orwell jokes among them: `Police Station`,
`Courthouse`, `Fire Station`, `Nuclear Power Plant`, `Corporate HQ`, `CEO
Residence`, `Intelligence HQ` — which under an Arch-Conservative regime become
`Death Squad HQ`, `Halls of Ultimate Judgment`, `Fireman HQ`, `Nuclear Waste
Center`, `CEO Castle`, and the **Ministry of Love** (`Miniluv`) and **Ministry
of Peace** (`Minipax`). If you add a building, give it a plain name and a
renamed form for a country that has gone.

Cities are real and abbreviated for columns: Seattle `SEA`, Los Angeles `LA`,
New York `NYC`, Chicago `CHI`, Detroit `DET`, Atlanta `ATL`, Miami `MI`,
Washington, DC `DC`. Districts: `Downtown`, `University District` (`U-District`),
`Shopping`, `Industrial District` (`I-District`), `City Outskirts`.

---

## Vocabulary that changes with the law

The single most important pattern in the game. Same sentence, different noun,
selected by `law[...]`. When you write anything that touches a contested issue,
find the seam and put the law on it.

**Abortion** (`LAW_ABORTION`, worst to best):
`illegal abortion-murders` → `illegal abortions` → `semi-legal abortions` →
`abortions`

**Flag burning** (`LAW_FLAGBURNING`):
`Flag Murder` → `felony flag burning` → `flag burning` → *not a crime at all*

**Immigration** (`LAW_IMMIGRATION`):
`hiring an illegal alien` / `hiring illegal aliens` →
`hiring an undocumented worker` / `hiring undocumented workers`

**Policy names** flip with who is proposing them, and the flip is the joke —
the original renamed these deliberately, and the old names survive in comments:

| Liberal framing | Conservative framing |
|---|---|
| Strengthen Reproductive Freedom | *(was Strengthen Abortion Rights)* |
| Stop Barbaric Executions | *(was Limit the Death Penalty)* |
| Fight Income Inequality | Cut Job-Killing Taxes |
| Protect our Environment | Support American Manufacturing |
| Protect Workers' Rights | Fight Corrupt Union Thugs |
| Prevent Mass Shootings | Protect our Second Amendment Rights |
| Prevent Nuclear Meltdowns | Promote Alternative Energy Sources |
| Fight Homophobic Bigotry in our Laws | — |
| Promote Transparency and Accountability | *(was Allow Corporations Access to Information)* |
| Help Scientists Cure Diseases | *(was Expand Animal Research)* |

Both sides use warm words for the thing they want. Nobody in this game names
their own policy honestly. Write new policies the same way.

---

## The censorship tiers

`LAW_FREESPEECH` rewrites the text itself, and the player sees the seams.

| law | printed |
|---|---|
| Elite Liberal (`2`) | `goddamn` · `pissing out the window` |
| middle | `g*dd*mn` |
| Arch-Conservative (`-2`) | `[gosh darn]` · `[relieving themselves] out the window` |

Under `-2` the whole news desk goes euphemistic, in visible brackets:

```
A student has gone on a [hurting spree] at a local high school.
[take] the president [on vacation]        [put] fertilizer [on plants]
[land] planes [on apartment buildings]    [cause a traffic jam on] a major bridge
[give children owies and boo-boos]        [show up uninvited on] a warship
detonate [fireworks] in New York          throwing [juice boxes]
has resigned in disgrace after being caught with a [civil servant].
the judge [going to the bathroom in the vicinity of] the [civil servant].
screamed "[darn] the police those [big dumb jerks]. I got a [stupid] ticket
this morning and I'm [so angry]."
```

The bracket convention also marks a euphemism the *game* is using for comic
effect regardless of law — `[makes a mess]`, `[makes a stinky]`, `[red water]`,
`something [good] about Jesus, and dies.` Use it where the plain word would be
too much and the euphemism is funnier.

When you write a censorable line, write the honest version and the bracketed
version, and let the law choose.

---

## Charges

The indictment names, from `src/monthly/justice.cpp`. The port has these in
`DossierText.CHARGES`. Repeats are counted: `3 counts of arson`.

treason · terrorism · murder · kidnapping · bank robbery · arson · sedition ·
drug dealing · escaping prison · aiding a prison escape · jury tampering ·
racketeering · extortion · felony assault · misdemeanor assault · grand theft
auto · credit card fraud · petty larceny · prostitution · interference with
interstate commerce · unlawful access of an information system · unlawful
burial · breaking and entering · vandalism · resisting arrest · disturbing the
peace · indecent exposure · loitering

Note the register: these are what a clerk reads out, not what the squad did.
"Liberal Trespassing" is what the *game* calls it when a Conservative shouts.

---

## Health in one word

`printhealthstat()`, long form and the eight-character column form. Ported to
`ui/adapters/condition_text.gd`.

Deceased · Near Death `NearDETH` · Badly Wounded `BadWound` · Wounded ·
Lightly Wounded `LtWound` · Neck Broken `NckBroke` · Quadraplegic `Quadpleg` ·
Paraplegic `Parapleg` · Face Gone `FaceGone` · No Limbs · One Limb · No Arms ·
No Legs · One Arm, One Leg `1Arm1Leg` · One Arm · One Leg · Blind · Face
Mutilated `FaceMutl` · Missing Nose `NoseGone` · Missing Eye `One Eye` · No
Tongue `NoTongue` · No Teeth · Missing Teeth `MisTeeth` · and if nothing at all
is wrong, the word is which side you are on: **Liberal**, **Moderate**,
**Conservative** `Consrvtv`, or **Animal**.

That last line is the whole game in one design decision. Health and politics
are the same column.

Wound words per body part: `Ripped off` · `Severed` · `Shot` · `Bruised` ·
`Cut` · `Torn` · `Burned`, and an unhurt part reads `Liberal`.

---

## Ranks

By Juice, and by which side you are on. From `gettitle()`.

**Liberal:** Damn Worthless → Society's Dregs → Punk → Civilian → Activist →
Socialist Threat → Revolutionary → Urban Commando → Liberal Guardian → **Elite
Liberal**

**Moderate:** Damn Worthless → Society's Dregs → Non-Liberal Punk →
Non-Liberal → Hard Working → Respected → Upstanding Citizen → Great Person →
Peacemaker → **Peace Prize Winner**

**Conservative:** Damn Worthless → Conservative Dregs → Conservative Punk →
Mindless Conservative → Wrong-Thinker → Stubborn as Hell → Heartless Bastard →
Insane Vigilante → Arch-Conservative → **Evil Incarnate**

Under censorship: `[Darn] Worthless`, `Stubborn as [Heck]`, `Heartless [Jerk]`.

---

## Activity names

Gerund, Title Case, and unglamorous. `Recruiting` · `Repairing Clothing` ·
`Procuring a Wheelchair` · `Stealing a Car` · `Gathering Opinion Info` ·
`Causing Trouble` · `Prostituting` · `Volunteering` · `Making Graffiti` ·
`Credit Card Fraud` · `Extorting Websites` · `Hacking Networks` · `Selling
T-Shirts` · `Teaching Covert Ops` · `Disposing of Bodies` · `Soliciting
Donations` · `Selling Brownies` · `Tending to Injuries` · `Laying Low` ·
`Writing letters` · `Going to Free CLINIC` · `Attending Classes` · `Promoting
Liberalism` · `Spouting Conservatism` · `Snooping Around` · `Quitting Job` ·
`Creating a Scandal` · `Embezzling Funds` · `Augmenting Liberal`

`Tending to a Hostage` is really `Tending to ` plus the hostage's name, and
falls back to `Tending to a bug` when the name is gone. That fallback is the
kind of joke the game makes and then never mentions again.

---

## Naming new things

Items are named the way a pawn shop labels them, not the way a fantasy game
does: `.38 Revolver`, `Combat Knife`, `Black Catsuit`, `Cheap Suit`, `Lab
Coat`, `Dirty Sock`, `Macaroni Art`, `Kitschy Trinket`, `Fine Jewelery`,
`Intel. HQ Data Disk`, `Judge Corrupt. Evidence`, `Secret Corporate Files`.
Note the abbreviations — column widths are nine or fourteen characters and the
truncations (`Army BodyArmor`, `MachinGun Drum`, `.44 Mag`) are part of the
texture. Keep them ugly.

The exceptions are the joke shop items — `Sword of Morfiegor`, `Maul of Anrin`,
`Dwarven Hammer`, `Elephant Suit`, `Donkey Suit`, `Clown Suit` — which are
funny *because* everything around them is a receipt.

Augmentation descriptions are the one place the game does mad-science ad copy,
straight-faced:

> *Iron is a vital chemical for humans, so by infusing the legs of this Liberal
> with steel, they will be more ready than ever to take on any Conservative
> challenge that they will run into.*

> *Our scientists have found the ultimate chemical formula that gives a Liberal
> the ultimate tanned calves. Behold, may all who lay eyes upon them be trapped
> by their beauty.*

Person names come from the generator in `src/creature/creaturenames.cpp` — a
few thousand real first and last names. Never invent a character name by hand;
pull one, so nobody in the world is authored to matter.
