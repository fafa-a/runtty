import { createSignal } from "solid-js"
import { Sidebar } from "~/components/ui/sidebar"
import "./App.css"

interface Project {
  name: string
  path: string
}

// WebUI global type
declare global {
  interface Window {
    webui?: {
      call: (eventId: string, data?: string) => Promise<string>
    }
  }
}

// API base URL - detect if running in WebUI or standalone
const getApiBase = () => {
  // If running in WebUI context, use relative URL
  // Otherwise, we need to know the host URL
  return ""
}

async function callApi(endpoint: string, body?: object): Promise<any> {
  const url = endpoint.startsWith("http") ? endpoint : `${getApiBase()}${endpoint}`
  
  // Try window.webui first (WebUI context)
  if (window.webui) {
    const data = body ? JSON.stringify(body) : ""
    const response = await window.webui.call(endpoint, data)
    return JSON.parse(response)
  }
  
  // Fallback: HTTP fetch for external browser
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  })
  
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${await response.text()}`)
  }
  
  return response.json()
}

function App() {
  const [projects, setProjects] = createSignal<Project[]>([])
  const [error, setError] = createSignal<string | null>(null)

  const handleOpenFile = async () => {
    setError(null)

    try {
      // Call backend API - works both in WebUI and external browser
      const data = await callApi("/api/folder/pick")

      if (data.error) {
        if (data.error === "user_cancelled") {
          return
        }
        setError(`Error: ${data.error}`)
        setProjects([])
        return
      }

      if (!data.folders || data.folders.length === 0) {
        setError("No subdirectories found in selected folder")
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
    console.log(`Play project: ${project.name} at ${project.path}`)
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
