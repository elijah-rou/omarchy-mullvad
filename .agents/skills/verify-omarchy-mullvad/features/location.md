# Location

A logged-in user picks the relay country or city from a picker in the panel. The picker opens from the Location row or with `/`, filters as the user types, and expands a country's cities. Picking while disconnected also connects, and picking while connected moves the tunnel.

## Sub-features

- `picker-open-row`: `Return` on the Location row opens the picker and chooses nothing.
- `picker-open-slash`: `/` opens the picker with the search field focused.
- `expand-collapse`: `l` and `h` expand and collapse a country with several cities.
- `pick-click`: clicking a country row chooses it, and connects while disconnected.
- `pick-search`: typing filters countries and cities, and `Return` chooses the first match.
- `escape`: `Escape` closes the picker and leaves the panel open.

## How to get to it (user POV)

- Open the panel, move to the Location row, and press `Return`.
- Open the panel and press `/`.
- In the picker, move with `j`/`k` or the arrows, and press `l` or `h` on a country.
- Click a country or city row.
- Type in `Search countries and cities`, then press `Return`.
- Press `Escape` in the picker or its search field.

## Driving it with verify-omarchy-mullvad

Preconditions:

- Drive target: `verify-omarchy-mullvad drive location`.
- `verify-omarchy-mullvad doctor` passes for this run.
- The stub daemon is logged in and disconnected, with location Gothenburg. The drive seeds it.

- **Open from the row.** After `ipc open`, move the cursor to the Location row (second row) and run `keys Return`. The panel shows `Search countries and cities`, `Albania`, `Germany`, and `Gothenburg`, and the stub records no `mullvad relay` call.
- **Expand and collapse.** `keys Down Down` moves to Germany. `keys --text l` shows `Berlin`, `Dusseldorf`, and `Frankfurt` and hides Sweden's cities. `keys --text h` hides `Berlin`.
- **Escape.** `keys Escape` closes the picker. `Change location` shows again, and the panel stays open.
- **Pick by click.** `keys --text /` opens the picker. `verify-omarchy-mullvad click --text Albania` records `mullvad relay set location al`, then `mullvad connect`. Status becomes `Connected`, `settings.json` holds `{"country": "al"}`, and the panel shows `Tirana, Albania`.
- **Escape from search.** `keys --text /`, then `keys Escape`, closes the picker.
- **Pick by search.** `keys --text /` and `keys --text stock` show `Stockholm` and hide Germany. `keys Return` records `mullvad relay set location se sto` and no `mullvad connect`, since the tunnel is already up. `settings.json` holds `{"country": "se", "city": "sto"}`, and the panel shows `Stockholm, Sweden`.
- **Open from the row after a search pick.** `keys Return` on the Location row, where the cursor sits after a pick, shows `Search countries and cities`. The stub records no `mullvad relay` call within 1.5 seconds.

## Gotchas

- The current location's name appears in the Location row title. Use a city of another country when checking that a list is collapsed.
- After a pick, the cursor stays on the Location row with the picker closed.
- On main at c993533, the last step fails. `Return` on the Location row right after a search pick reopens the picker and immediately chooses a row. The drive keeps that check: it describes what the user expects.
