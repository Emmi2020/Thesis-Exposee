# Internship Report — LaTeX build via Docker

LaTeX is **not installed on Windows**. The document is compiled inside a Docker
container, so no TeX distribution touches the host system.

## Folder structure

```
src/        LaTeX sources — the only folder mounted into the container
docker/     Image definition (Dockerfile, .dockerignore)
build/      Generated output (PDF, logs, font cache) — safe to delete
.vscode/    VS Code build wiring
```

## Files that make this work

| File | Purpose |
| --- | --- |
| [src/main.tex](src/main.tex) | Root document. The only file that gets compiled. Pulls in the preamble and the front matter. |
| [src/preamble.tex](src/preamble.tex) | Package list and formatting. Included by `main.tex`, not compiled on its own. |
| [src/Frontmatter/titlepage.tex](src/Frontmatter/titlepage.tex) | Title page, included by `main.tex`. |
| [docker/Dockerfile](docker/Dockerfile) | Defines the container image: Debian + TeX Live + `latexmk` + `biber`. |
| [docker/.dockerignore](docker/.dockerignore) | Keeps the image build context to just the `Dockerfile`. |
| [build-latex.ps1](build-latex.ps1) | Builds the image if missing, then runs the compile in a locked-down container. |
| [.vscode/settings.json](.vscode/settings.json) | Points LaTeX Workshop at the Docker build instead of a local TeX install. |
| [.vscode/tasks.json](.vscode/tasks.json) | Makes `Ctrl+Shift+B` run the Docker build. |
| [.gitignore](.gitignore) | Excludes the generated `build/` folder. |

Output goes to `build/main.pdf`. The `build/` folder also holds `main.log` and
the font cache; it can be deleted at any time.

Only `src/` is mounted into the container, so every file referenced by the
document must live inside `src/`.

## Prerequisites

- Docker Desktop, running (check with `docker info`).
- VS Code extension **LaTeX Workshop** (already installed).

## How to build

Either:

- Press `Ctrl+Shift+B` in VS Code, or
- Open [src/main.tex](src/main.tex) and run **LaTeX Workshop: Build LaTeX project**, or
- Run in PowerShell from the project folder:

```powershell
.\build-latex.ps1
```

To view the result: **LaTeX Workshop: View LaTeX PDF**, or open `build/main.pdf`.

The first build downloads the Debian base image and TeX Live and takes a while.
Later builds reuse the cached image and are fast.

## What the build script actually does

1. Checks that the `docker` command exists and the engine is running.
2. If the image `praktikumsbericht-latex:local` does not exist, builds it from
   [docker/Dockerfile](docker/Dockerfile).
3. Creates `build/` and `build/.texmfvar` (persistent font cache — without it,
   LuaTeX regenerates its font database on every run).
4. Runs `latexmk -lualatex` inside a throwaway container.

The container is restricted:

| Flag | Effect |
| --- | --- |
| `--network none` | No internet access during compilation. |
| `--read-only` + read-only `src/` mount | The container cannot modify your source files. |
| `--mount ... target=/output` | Only `build/` is writable. |
| `--cap-drop ALL`, `--security-opt no-new-privileges` | No Linux capabilities, no privilege escalation. |
| `--pids-limit`, `--memory`, `--cpus` | Limits runaway processes. |
| `--rm` | Container is deleted after each run. |

`--shell-escape` is deliberately **not** enabled.

## Fonts

The preamble asks for Verdana, which does not exist on Debian. Two things make
it work:

- `build-latex.ps1` mounts `C:\Windows\Fonts` into the container **read-only**
  at `/hostfonts` and sets `OSFONTDIR=/hostfonts`, so LuaTeX can find the
  Windows fonts. The fonts stay on your licensed machine and are never copied
  into the image.
- [src/preamble.tex](src/preamble.tex) falls back to TeX Gyre Heros if Verdana is
  missing, so the document still compiles elsewhere.

## Adding a LaTeX package

The image uses `texlive-full`, so almost every CTAN package is already present.
If something is still missing, add the Debian package to
[docker/Dockerfile](docker/Dockerfile) and rebuild the image explicitly (the
script only builds when the image is absent):

```powershell
docker build --tag praktikumsbericht-latex:local .\docker
```

To find which Debian package provides a missing `.sty`:

```powershell
docker run --rm praktikumsbericht-latex:local bash -c "apt-get update -qq && apt-file search ulem.sty"
```

## Troubleshooting

Compilation errors are reported by the script and written to `build/main.log`.
To see the actual LaTeX error rather than the whole log:

```powershell
Select-String -Path .\build\main.log -Pattern '^!' -Context 0,6
```

Problems hit during setup, and their fixes:

- *Cannot find LaTeX root PDF to view* — there was no root document; only a
  preamble and a title page fragment. Fixed by adding [src/main.tex](src/main.tex) and
  `% !TeX root` comments in the included files.
- *File `ulem.sty` not found* — package missing from the image. Fixed by
  installing the appropriate TeX Live package in
  [docker/Dockerfile](docker/Dockerfile).
- *Undefined control sequence ... `\undefinedpagestyle`* — the title page had a
  template placeholder `\thispagestyle{empty/plain/headings/myheadings}`.
  Replaced with `\thispagestyle{empty}`.
- *Argument of `\@textcolor` has an extra `}`* — `\textcolor{TitleBlue}` was
  written without its second argument. It needs
  `\textcolor{TitleBlue}{Internship Report}`.

## Zotero for citations and references

Yes, this works, and the project is already set up for it. [src/preamble.tex](src/preamble.tex)
loads `biblatex` with the `biber` backend and points at `src/preferences.bib`:

```latex
\usepackage[backend=biber, style=numeric-comp, ...]{biblatex}
\addbibresource{preferences.bib}
```

Zotero's job is simply to keep that `.bib` file filled in. Nothing about the
Docker setup needs to change — `biber` is already installed in the image and
runs automatically as part of `latexmk`.

### One-time setup

1. Install Zotero, plus the **Better BibTeX** plugin (`zotero.org`, then
   `retorque.re/zotero-better-bibtex`). Better BibTeX is what gives stable,
   readable citation keys such as `muhire2026internship` instead of Zotero's
   internal ones.
2. In Zotero: *Edit → Settings → Better BibTeX → Citation keys*, set a key
   format (the default `auth.lower + year + shorttitle` is fine).
3. Right-click your Zotero collection → **Export Collection…**
   - Format: **Better BibLaTeX** (not BibTeX — BibLaTeX matches the `biblatex`
     package used here)
   - Tick **Keep updated**
   - Save it as `src/preferences.bib`, overwriting the placeholder.

"Keep updated" is the important part: Zotero rewrites that file automatically
whenever you add or edit a source, so the `.bib` is never manually maintained.

### Using it in the document

```latex
Steel is widely used \cite{smith2020}.
As \textcite{smith2020} showed, ...
\autocite{smith2020}
```

`cleveref` and `hyperref` are already loaded, so citations become clickable
links.

The bibliography itself is **not printed yet**. Add this near the end of
[src/main.tex](src/main.tex), before `\end{document}`:

```latex
\printbibliography[heading=bibintoc, title={References}]
```

`heading=bibintoc` adds it to the table of contents.

### Inserting citations from VS Code

Two options, both without leaving the editor:

- **LaTeX Workshop autocomplete (works immediately):** type `\cite{` and the
  extension lists every entry in `preferences.bib`, since it parses
  `\addbibresource` itself.
- **Pick from Zotero's own search dialog:** requires Better BibTeX. Add to
  [.vscode/settings.json](.vscode/settings.json):

  ```json
  "latex-workshop.zotero.citeMethod": "cite-as-you-write"
  ```

  Then run **LaTeX Workshop: Cite from Zotero** (bind it to a key if you use it
  often). Zotero must be running; it talks to it on `127.0.0.1:23119`.

### Things to watch

- The `.bib` file must stay under `src/` — that is the only folder mounted into
  the container.
- Export as **Better BibLaTeX**, not Better BibTeX. Exporting plain BibTeX gives
  fields (like `journaltitle` vs `journal`) that `biblatex` handles differently.
- After adding sources, build twice if references show as `[?]`. `latexmk`
  normally resolves this on its own, but a stale `build/` can hold old data —
  delete `build/` and rebuild if a reference stays broken.
- Keep Zotero's export target out of OneDrive conflict territory: if OneDrive
  creates `preferences-Kopie.bib`, the export path drifted — re-point it.
- Commit `preferences.bib` to version control. It is generated, but it is the
  only record of your sources that the document itself needs.

## Starting fresh

```powershell
Remove-Item -Recurse -Force .\build
docker image rm praktikumsbericht-latex:local
```

The next build recreates both.

## Matching a Word template structure

The attached Word template was not saved into the workspace, so the exact
headings cannot be extracted yet. To mirror it precisely, save the `.docx` file
into the project folder and inspect its table of contents or headings. Then map
each top-level heading to one LaTeX file.

A typical English internship report or later thesis can grow like this:

```
src/
  main.tex
  preamble.tex
  Frontmatter/
    titlepage.tex
    abstract.tex
    declaration.tex
  Chapters/
    01-introduction.tex
    02-company-profile.tex
    03-tasks-and-projects.tex
    04-methodology.tex
    05-results.tex
    06-reflection.tex
    07-conclusion.tex
  Appendix/
    A-additional-figures.tex
    B-source-code.tex
    C-datasheets.tex
  Resources/
    Images/
    Tables/
    PDFs/
  preferences.bib
```

Keep [src/main.tex](src/main.tex) as the document map. It should mostly list
files in reading order:

```latex
\begin{document}

\input{Frontmatter/titlepage}
\input{Frontmatter/abstract}
	ableofcontents
\listoffigures
\listoftables

\include{Chapters/01-introduction}
\include{Chapters/02-company-profile}
\include{Chapters/03-tasks-and-projects}
\include{Chapters/04-methodology}
\include{Chapters/05-results}
\include{Chapters/06-reflection}
\include{Chapters/07-conclusion}

\printbibliography[heading=bibintoc, title={References}]

\appendix
\include{Appendix/A-additional-figures}
\include{Appendix/B-source-code}

\end{document}
```

For a thesis, use the same structure but rename the middle chapters around your
research question, for example: `Related Work`, `Requirements`, `Design`,
`Implementation`, `Evaluation`, and `Conclusion`.

When you are ready to create chapter files, put this as the first line in each
included file:

```latex
% !TeX root = ../main.tex
```

Use `\chapter{Title}` for files in `Chapters/` and `Appendix/`. Use `\input`
for short frontmatter files that should not force a chapter-style page break.

## Growing the document into chapters and appendices

Nothing below is set up yet — this is the recipe for when the document gets
bigger.

### Suggested layout

```
src/
  main.tex              root document, only lists what to include
  preamble.tex          packages and formatting
  Frontmatter/          title page, abstract, declaration
  Chapters/             01-introduction.tex, 02-company.tex, ...
  Appendix/             A-datasheets.tex, B-code.tex, ...
  Resources/Images/     figures
  preferences.bib       bibliography
```

Number the chapter files (`01-`, `02-`) so the file order matches the document
order.

### Wiring them into `main.tex`

```latex
\begin{document}

\input{Frontmatter/titlepage}
\tableofcontents

\include{Chapters/01-introduction}
\include{Chapters/02-company}

\appendix
\include{Appendix/A-datasheets}

\end{document}
```

Each chapter file starts with `\chapter{...}` and, as its first line, a root
hint so LaTeX Workshop knows what to compile when that file is open:

```latex
% !TeX root = ../main.tex
```

### `\include` vs `\input`

| | `\include{...}` | `\input{...}` |
| --- | --- | --- |
| Page break before/after | yes | no |
| Works for chapters | yes | yes |
| Writes its own `.aux` file | **yes** | no |
| Supports `\includeonly` | yes | no |

`\includeonly{Chapters/03-methods}` recompiles just one chapter while keeping
all cross-references and page numbers — very useful once the document is long.

Use `\input` for fragments that must not start a new page (title page, a table,
a snippet).

### The one container-specific trap

Because the build compiles with `-outdir=/output`, `\include{Chapters/01-intro}`
tries to write `/output/Chapters/01-intro.aux`. LaTeX does **not** create that
subfolder, so the run fails with something like:

```
! I can't write on file `Chapters/01-introduction.aux'.
```

Fix it by mirroring the `src/` folder tree into `build/` before compiling. Add
this to [build-latex.ps1](build-latex.ps1), just after `$fontCacheDirectory` is
created:

```powershell
# \include writes an .aux per file, so build/ must mirror the src/ folder tree.
Get-ChildItem -Path $sourceDirectory -Directory -Recurse | ForEach-Object {
    $mirrored = Join-Path $buildDirectory $_.FullName.Substring($sourceDirectory.Length + 1)
    New-Item -ItemType Directory -Force -Path $mirrored | Out-Null
}
```

If you only ever use `\input`, this is not needed.

### Images from any folder

Add this to `main.tex` (after the preamble) so chapters can reference figures by
file name instead of a long relative path:

```latex
\graphicspath{{Resources/Images/}}
```

Then `\includegraphics{HAW_Kiel_Logo.png}` works from any chapter file. Multiple
folders are allowed: `\graphicspath{{Resources/Images/}{Resources/Plots/}}`.

### Rules that keep it working in the container

- Everything referenced must live under `src/` — that is the only folder mounted.
- Paths are **case-sensitive** inside Linux: `Resources/Images/Logo.png` and
  `resources/images/logo.png` are different files.
- Always use forward slashes, never `\`.
- Avoid spaces in file names.
- After adding a bibliography, `biber` runs automatically via `latexmk`; the
  `.bib` file must also be under `src/`.

## Reusing this setup for a thesis

The infrastructure is not specific to this report. For a new document, create a
new folder and copy five things into it:

```
docker/Dockerfile
docker/.dockerignore
build-latex.ps1
.vscode/settings.json
.vscode/tasks.json
```

Then create `src/main.tex` and press `Ctrl+Shift+B`.

One change worth making first: the image tag in [build-latex.ps1](build-latex.ps1)
is `praktikumsbericht-latex:local`. Rename it to something neutral, e.g.

```powershell
$image = "latex-lualatex:local"
```

The Dockerfile contains nothing project-specific, so every project can share one
image. Without this, each new project rebuilds its own multi-gigabyte copy of
`texlive-full`; with it, new projects build immediately.

