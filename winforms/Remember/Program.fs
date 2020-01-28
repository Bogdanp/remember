open System
open System.Windows.Forms

[<EntryPoint>]
[<STAThread>]
let main argv =
    Application.EnableVisualStyles()
    Application.SetCompatibleTextRenderingDefault true
    use form = new Form()
    Application.Run(form)
    0
