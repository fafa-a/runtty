import { createSignal } from "solid-js"
import { Sidebar } from "~/components/ui/sidebar"
import "./App.css"

interface Project {
  name: string
  path: string
}

// WebUI is loaded via script tag in index.html
declare const webui: {
  call: (eventId: string, data?: string) => Promise<string>
}

function App() {
  const [projects, setProjects] = createSignal<Project[]>([])
  const [error, setError] = createSignal<string | null>(null)

  const handleOpenFile = async () => {
    setError(null)

    try {
      // Call backend via WebUI
      const response = await webui.call("folder.pick")
      const data = JSON.parse(response)

      if (data.error) {
        if (data.error === "user_cancelled") {
          return
        }
        setError(`Error: ${data.error}`)
        setProjects([])
        return
      }

      if (!data.folders || data.folders.length === 0) {
        setError("No subdirectories found")
        setProjects([])
      } else {
        const newProjects = data.folders.map((name: string) => ({
          name,
          path: `${data.path}/${name}`,
        }))
        setProjects(newProjects)
        setError(null)
      }
    } catch (err) {
      console.error("Failed to pick folder:", err)
      setError(`Failed: ${err instanceof Error ? err.message : String(err)}`)
    }
  }

  const handlePlay = (project: Project) => {
    console.log(`Play project: ${project.name}`)
  }

  const handleStop = (project: Project) => {
    console.log(`Stop project: ${project.name}`)
  }

  return (
    <div class="h-screen flex bg-background text-foreground">
      <Sidebar
        projects={projects()}
        onOpenFile={handleOpenFile}
        onPlay={handlePlay}
        onStop={handleStop}
      />

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
