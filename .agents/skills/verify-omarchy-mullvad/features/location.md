# Location

A logged-in user picks the relay country or city from a picker in the panel. The picker opens from the Location row or with `/`, filters as the user types, and expands a country's cities. Picking while disconnected also connects, and picking while connected moves the tunnel.

## Sub-features

- `picker-open-row`: `Return` on the Location row opens the picker and chooses nothing.
- `picker-open-slash`: `/` opens the picker with the search field focused.
- `expand-collapse`: `l` and `h` expand and collapse a country with several cities.
- `pick-click`: clicking a country row chooses it, and connects while disconnected.
- `pick-search`: typing filters countries and cities, and one `Return` chooses the first match and closes the picker.
- `held-return`: a held `Return` chooses nothing on the Location row and chooses once in the search.
- `escape`: `Escape` closes the picker and leaves the panel open.

## How to get to it (user POV)

- Open the panel, move to the Location row, and press `Return`.
- Open the panel and press `/`.
- In the picker, move with `j`/`k` or the arrows, and press `l` or `h` on a country.
- Click a country or city row.
- Type in `Search countries and cities`, then press or hold `Return`.
- Hold `Return` on the Location row.
- Press `Escape` in the picker or its search field.

## Driving it with verify-omarchy-mullvad

Preconditions:

- Drive target: `verify-omarchy-mullvad drive location`.
- `verify-omarchy-mullvad doctor` passes for this run.
- The stub daemon is logged in and disconnected, with location Gothenburg. The drive seeds it.

- **Picker open and closed.** The Location row's detail reads `Choose a country or city` while the picker is open and `Change location` while it is closed. Every check of the picker's state requires one and rejects the other, plus `countries and cities` (from the search placeholder) for open.
- **Open from the row.** After `ipc open`, move the cursor to the Location row (second row) and run `keys Return`. The picker is open and shows `Albania`, `Germany`, and `Gothenburg`, and the stub records no `mullvad relay` call.
- **Expand and collapse.** `keys Down Down` moves to Germany. `keys --text l` shows `Berlin`, `Dusseldorf`, and `Frankfurt` and hides Sweden's cities. `keys --text h` hides `Berlin`.
- **Escape.** `keys Escape` closes the picker, and the panel stays open.
- **Pick by click.** `keys --text /` opens the picker. `verify-omarchy-mullvad click --text Albania` records `mullvad relay set location al`, then `mullvad connect`. Status becomes `Connected`, `settings.json` holds `{"country": "al"}`, and the panel shows `Tirana, Albania` with the picker closed.
- **Escape from search.** `keys --text /`, then `keys Escape`, closes the picker.
- **Pick by search.** `keys --text /` and `keys --text stock` show `Stockholm` and hide Germany. `keys Return` records `mullvad relay set location se sto` and no `mullvad connect`, since the tunnel is already up. `settings.json` holds `{"country": "se", "city": "sto"}`, and the panel shows `Stockholm, Sweden` with the picker closed.
- **Open from the row after a search pick.** `keys Return` on the Location row, where the cursor sits after a pick, opens the picker. The stub records no `mullvad relay` call within 1.5 seconds. `keys Escape` closes it.
- **Held Return on the row.** A 1.5-second hold of `Return` on the Location row (`wtype -P Return -s 1500 -p Return` into the run's compositor) opens the picker, and the stub records no `mullvad relay` call within 1.5 seconds. `keys Escape` closes it.
- **Held Return in the search.** `keys --text /`, then a 1.5-second hold of `x` fills the search with repeated `x`, which shows the hold arrives as autorepeat. A held `BackSpace` clears it. `keys --text malm` shows `Malmö` and `Sweden` and hides Germany and Albania. A 1.5-second hold of `Return` records `mullvad relay set location se mma` and no other `mullvad relay` call within 1.5 seconds, and `settings.json` holds `{"country": "se", "city": "mma"}`.

## Gotchas

- The current location's name appears in the Location row title. Use a city of another country when checking that a list is collapsed.
- After a pick, the cursor stays on the Location row with the picker closed.
- OCR reads the search placeholder's `Search` as `bearch`, so a check for the absence of `Search countries` passes while the picker is open. Check the Location row's detail instead, as the drive does.
- Before f478e7f (#3), one `Return` in the search picks and leaves the picker open, so the check after the search pick fails, and a held `Return` on the Location row or in the search picks Albania again and again. The drive keeps those checks: they describe what the user expects.
- The compositor's key repeat is pinned at a 600 ms delay and 25 per second in the run's Hyprland config, so a 1.5-second hold gives about 20 autorepeats.
- After a held `Return` in the search picks, the remaining autorepeats reach the panel and reopen the picker on the Location row. The drive does not assert the picker's state after that hold.
