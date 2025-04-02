add-type -name user32 -namespace win32 -memberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
$consoleHandle = (get-process -id $pid).mainWindowHandle
# Download JSON file and parse "bridge-download-url"
$jsonUrl = "https://raw.githubusercontent.com/AltyFox/MBFBridgeInstaller/refs/heads/main/config.json"
$jsonFilePath = "$env:TEMP\config.json"
Invoke-WebRequest -Uri $jsonUrl -OutFile $jsonFilePath
$jsonContent = Get-Content -Path $jsonFilePath -Raw | ConvertFrom-Json
$bridgeDownloadUrl = $jsonContent."bridge-download-url"
# Create a variable for the base64 icon



Add-Type -AssemblyName System.Windows.Forms

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "MBF Bridge Installer"
$form.Size = New-Object System.Drawing.Size(800,500)
$form.StartPosition = "CenterScreen"



# Get the icon of the current executable and set it as the form's icon
$currentExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($currentExePath)

# Create Label
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,10)
$label.Size = New-Object System.Drawing.Size(760,50)
$label.Font = New-Object System.Drawing.Font("Arial",14,[System.Drawing.FontStyle]::Bold)
$label.Text = "Welcome to the MBF Bridge Installer. Click 'Start' to begin."
$form.Controls.Add($label)

# Create TextBox for output
$outputBox = New-Object System.Windows.Forms.TextBox
$outputBox.Multiline = $true
$outputBox.ScrollBars = "Vertical"
$outputBox.Location = New-Object System.Drawing.Point(10,70)
$outputBox.Size = New-Object System.Drawing.Size(760,280)
$outputBox.Font = New-Object System.Drawing.Font("Consolas",12,[System.Drawing.FontStyle]::Regular)
$form.Controls.Add($outputBox)

# Create Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 360)
$progressBar.Size = New-Object System.Drawing.Size(760, 25)
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

# Create Start Button
$startButton = New-Object System.Windows.Forms.Button
$startButton.Location = New-Object System.Drawing.Point(10,400)
$startButton.Size = New-Object System.Drawing.Size(100,40)
$startButton.Text = "Start"
$form.Controls.Add($startButton)








# Helper function for logging
Function Log-Message($message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $outputBox.AppendText("`r`n[$timestamp] $message")
    $outputBox.ScrollToCaret()
}

# Function to download a file with progress


function DownloadFile($url, $targetFile)
{
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) # 15-second timeout
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = New-Object byte[] 10240  # 10KB buffer
   $count = $responseStream.Read($buffer, 0, $buffer.length)
   $downloadedBytes = $count

   # Ensure progress bar exists before modifying it
   if ($progressBar -ne $null) {
       $progressBar.Visible = $true
       $progressBar.Value = 0
   }

   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer, 0, $buffer.length)
       $downloadedBytes += $count

       # Update progress bar
       if ($progressBar -ne $null -and $totalLength -gt 0) {
           $progressBar.Value = [System.Math]::Min(100, ([System.Math]::Floor($downloadedBytes/1024) / $totalLength) * 100)
       }
   }

   # Hide progress bar after completion
   if ($progressBar -ne $null) {
       $progressBar.Value = 100
       Start-Sleep -Milliseconds 500  # Brief delay for UI update
       $progressBar.Visible = $false
   }

   # Cleanup
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
}



# Main Installation Function
$startButton.Add_Click({
    $startButton.Enabled = $false
    
    $tempDir = [System.IO.Path]::GetTempPath()
    Log-Message "Downloading the USB driver needed to access your Quest"
    $androidUSBPath = "$tempDir\AndroidUSB.zip"
    DownloadFile "https://github.com/AltyFox/MBFLauncherAutoInstaller/raw/refs/heads/main/AndroidUSB.zip" $androidUSBPath
    
    Log-Message "Extracting AndroidUSB.zip to: $tempDir\AndroidUSB"
    Expand-Archive -Path $androidUSBPath -DestinationPath $tempDir\AndroidUSB -Force
    Log-Message "Extraction completed."
    
    Log-Message "Installing USB driver from android_winusb.inf"
    $messageBox = [System.Windows.Forms.MessageBox]::Show(
        "This requires Admin privileges. You may see a prompt, please accept it. If you don't accept the prompt and install the drivers, MBF Bridge may not function correctly.",
        "Admin Privileges Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($messageBox -eq [System.Windows.Forms.DialogResult]::OK) {
        $infPath = "$tempDir\AndroidUSB\android_winusb.inf"
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"pnputil /add-driver `"$infPath`" /install`"" -Verb RunAs
        Log-Message "USB driver installed successfully."
    }
    
    Log-Message "Downloading the MBF Bridge from the provided URL."
    $bridgeZipPath = "$tempDir\MBFBridge.zip"
    DownloadFile $bridgeDownloadUrl $bridgeZipPath

    Log-Message "Extracting MBFBridge.zip to temporary directory."
    $bridgeExtractPath = "$tempDir\MBFBridge"
    Expand-Archive -Path $bridgeZipPath -DestinationPath $bridgeExtractPath -Force
    Log-Message "Extraction completed."

    Log-Message "Locating the MBF Bridge executable."
    $exeFile = Get-ChildItem -Path $bridgeExtractPath -Filter "*.exe" -Recurse | Select-Object -First 1
    if (-not $exeFile) {
        Log-Message "Error: No executable file found in the extracted archive."
        return
    }
    Log-Message "Found executable: $($exeFile.FullName)"

    $messageBox = [System.Windows.Forms.MessageBox]::Show(
        "You will now be asked where you want to save the MBF Bridge application. It will default to your Desktop. Choose where you want to save it.",
        "Save Location",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    if ($messageBox -ne [System.Windows.Forms.DialogResult]::OK) {
        Log-Message "Operation canceled by the user."
        return
    }

    # Kill any running process matching the name of the executable
    $processName = [System.IO.Path]::GetFileNameWithoutExtension($exeFile.Name)
    $runningProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue
    if ($runningProcesses) {
        Log-Message "Terminating running instances of $processName."
        $runningProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force }
        Log-Message "All running instances of $processName have been terminated."
    } else {
        Log-Message "No running instances of $processName found."
    }

    # Kill any running instance of adb.exe
    $adbProcesses = Get-Process -Name "adb" -ErrorAction SilentlyContinue
    if ($adbProcesses) {
        Log-Message "Terminating running instances of adb.exe."
        $adbProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force }
        Log-Message "All running instances of adb.exe have been terminated."
    } else {
        Log-Message "No running instances of adb.exe found."
    }

    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
    $saveFileDialog.Filter = "Executable Files (*.exe)|*.exe"
    $saveFileDialog.FileName = $exeFile.Name

    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $destinationPath = $saveFileDialog.FileName
        Log-Message "Saving executable to: $destinationPath"
        Copy-Item -Path $exeFile.FullName -Destination $destinationPath -Force
        Log-Message "Executable saved successfully."

        # Close the current form
        $form.Close()

        # Create a new form for the "How do I use this?" message
        $infoForm = New-Object System.Windows.Forms.Form
        $infoForm.Text = "How to Use MBF Bridge"
        $infoForm.Size = New-Object System.Drawing.Size(600, 300)
        $infoForm.StartPosition = "CenterScreen"

        # Create a label for the message
        $infoLabel = New-Object System.Windows.Forms.Label
        $infoLabel.Location = New-Object System.Drawing.Point(10, 10)
        $infoLabel.Size = New-Object System.Drawing.Size(560, 240)
        $infoLabel.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
        $infoLabel.Text = "How do I use this?`r`n`r`n" +
                  "When you open the executable, it will create an icon in your system tray.`r`n" +
                  "It will also automatically open the MBF Website.`r`n`r`n" +
                  "You can open MBF at any time by either opening the executable or by clicking the icon in your system tray.`r`n`r`n"+
                  "When you close this window, it will automatically open the application."
        $infoLabel.AutoSize = $false
        $infoLabel.TextAlign = "TopLeft"
        $infoLabel.BorderStyle = "FixedSingle"
        $infoLabel.Size = New-Object System.Drawing.Size(560, 200)
        $infoForm.Controls.Add($infoLabel)

        # Create a close button
        $closeButton = New-Object System.Windows.Forms.Button
        $closeButton.Text = "Close"
        $closeButton.Size = New-Object System.Drawing.Size(100, 30)
        $closeButton.Location = New-Object System.Drawing.Point(250, 220)
        $closeButton.Add_Click({ 
            Start-Process -FilePath $destinationPath
            $infoForm.Close()
        })
        $infoForm.Controls.Add($closeButton)

        # Show the new form
        [void]$infoForm.ShowDialog()
    } else {
        Log-Message "Save operation canceled by the user."
        Log-Message "Please re-run this application and save the file where you want it."
    }


})

# Show the form
[void]$form.ShowDialog()
