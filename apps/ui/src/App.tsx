import { createSignal } from "solid-js"
import { Sidebar } from "~/components/ui/sidebar"
import "./App.css"

// Déclaration pour webkitdirectory
declare module "solid-js" {
  namespace JSX {
    interface InputHTMLAttributes<T> {
      webkitdirectory?: boolean
      directory?: boolean
    }
  }
}

interface Project {
  name: string
  path: string
}

function App() {
  const [projects, setProjects] = createSignal<Project[]>([])
  const [error, setError] = createSignal<string | null>(null)
  let inputRef: HTMLInputElement | undefined

  const handleOpenFile = () => {
    setError(null)
    inputRef?.click()
  }

  const handleFileSelect = (e: Event) => {
    const target = e.target as HTMLInputElement
    const files = target.files
    console.log("files", files)

    if (!files || files.length === 0) {
      target.value = ""
      return
    }

    // Extraire les noms des sous-dossiers (niveau 1) depuis webkitRelativePath
    // Structure: selected-folder/subdirectory/file.txt
    // parts[0] = dossier sélectionné, parts[1] = sous-dossier (ce qu'on veut)
    const folderNames = new Set<string>()
    for (const file of files) {
      const path = file.webkitRelativePath
      if (path) {
        const parts = path.split("/")
        // On veut les enfants (parts[1]), pas le dossier sélectionné (parts[0])
        if (parts.length > 2) {
          folderNames.add(parts[1])
        }
      }
    }

    if (folderNames.size === 0) {
      setError("No subdirectories found")
      setProjects([])
    } else {
      const newProjects = Array.from(folderNames)
        .sort()
        .map((name) => ({ name, path: name }))
      setProjects(newProjects)
      setError(null)
    }

    // Reset input pour permettre re-sélection du même dossier
    target.value = ""
  }

  const handlePlay = (project: Project) => {
    console.log(`Play project: ${project.name}`)
  }

  const handleStop = (project: Project) => {
    console.log(`Stop project: ${project.name}`)
  }

  return (
    <div class="h-screen flex bg-background text-foreground">
      {/* Input caché pour sélection de dossier */}
      <input
        ref={inputRef}
        type="file"
        webkitdirectory
        style={{ display: "none" }}
        onChange={handleFileSelect}
      />

      <Sidebar
        projects={projects()}
        onOpenFile={handleOpenFile}
        onPlay={handlePlay}
        onStop={handleStop}
      />

      {/* Main Content */}
      <div class="flex-1 flex items-center justify-center p-8">
        <div class="text-center">
          <h1 class="text-3xl font-bold mb-4">RunTTY</h1>
          <p class="text-muted-foreground mb-4">
            Terminal Emulator avec WebView
          </p>
          <p class="text-sm text-muted-foreground">
            Utilisez la sidebar pour sélectionner un projet
          </p>
          {error() && (
            <p class="text-sm text-destructive mt-4">{error()}</p>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
