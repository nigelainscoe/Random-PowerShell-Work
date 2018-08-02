function Install-GnuPg {
    <#
	.SYNOPSIS
		This function installed the GnuPg for Windows application.  It the installer file is not in
		the DownloadFolderPath, the function will download the file from the Internet and then execute a silent installation.
	.PARAMETER  DownloadFolderPath
		The folder path where you'd like to download the GnuPg for Windows installer into.

	.PARAMETER  DownloadUrl
		The URL that will be used to download the EXE setup installer.

	.EXAMPLE
		PS> Install-GnuPg -DownloadFolderPath C:\Downloads

		This will first check to ensure the GnuPg for Windows installer is in the C:\Downloads folder.  If not, it will then
		download the file from the default URL set at DownloadUrl.  Once downloaded, it will then silently execute
		the installation and get the application installed with default parameters.

	.INPUTS
		None. This function does not accept pipeline input.

	.OUTPUTS
		None. If successful, this function will not return any output.
    #>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DownloadFolderPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DownloadUrl = 'http://files.gpg4win.org/gpg4win-2.2.5.exe'

    )
    process {
        try {
            $DownloadFilePath = "$DownloadFolderPath\$($DownloadUrl | Split-Path -Leaf)"
            if (-not (Test-Path -Path $DownloadFilePath -PathType Leaf)) {
                Write-Verbose -Message "Downloading [$($DownloadUrl)] to [$($DownloadFilePath)]"
                Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadFilePath
            }
            else {
                Write-Verbose -Message "The download file [$($DownloadFilePath)] already exists"
            }
            Write-Verbose -Message 'Attempting to install GPG4Win...'
            Start-Process -FilePath $DownloadFilePath -ArgumentList '/S' -NoNewWindow -Wait -PassThru
            Write-Verbose -Message 'GPG4Win installed'
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
}

function Add-Encryption {
    <#
	.SYNOPSIS
		This function uses the GnuPG for Windows application to symmetrically encrypt a set of files in a folder.

	.DESCRIPTION
		A detailed description of the function.

	.PARAMETER FolderPath
		This is the folder path that contains all of the files you'd like to encrypt.

	.PARAMETER  Password
		This is the password that will be used to encrypt the files.

	.EXAMPLE
		PS> Add-Encryption -FolderPath C:\TestFolder -Password secret

		This example would encrypt all of the files in the C:\TestFolder folder with the password of 'secret'.  The encrypted
		files would be created with the same name as the original files only with a GPG file extension.

	.INPUTS
		None. This function does not accept pipeline input.

	.OUTPUTS
		System.IO.FileInfo
	#>

    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( {Test-Path -Path $_ -PathType Container})]
        [string]$FolderPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Password,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$GpgPath = 'C:\Program Files (x86)\GNU\GnuPG\gpg2.exe'

    )
    process {
        try {
            Get-ChildItem -Path $FolderPath | ForEach-Object {
                Write-Verbose -Message "Encrypting [$($_.FullName)]"
                & $GpgPath --batch --passphrase $Password -c $_.FullName
            }
            Get-ChildItem -Path $FolderPath -Filter '*.gpg'
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
}

function Remove-Encryption {
    <#
	.SYNOPSIS
		This function decrypts all files encrypted with the Add-Encryption function. Once decrypted, it will add the files
		to the same directory that contains the encrypted files and will remove the GPG file extension.

	.PARAMETER FolderPath
		The folder path that contains all of the encrypted *.gpg files.

	.PARAMETER Password
		The password that was used to encrypt the files.

        .PARAMETER EncryptionSuffix
		The File extension of the files to be decrypted, e.g. .gpg or .pgp.

	.EXAMPLE
		PS> Remove-Encryption -FolderPath C:\MyFolder -Password secret -EncryptionSuffix '.foo'

        This example will attempt to decrypt all files inside of the C:\MyFolder folder with a 
        file extension of .foo using the password of 'secret'

	.INPUTS
		None. This function does not accept pipeline input.

	.OUTPUTS
		System.IO.FileInfo

	#>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path $_ -PathType Container })]
        [string]$FolderPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Password,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$GpgPath = 'C:\Program Files (x86)\GNU\GnuPG\gpg2.exe',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EncryptionSuffix = '.gpg'
    )
    process {
        try {
 
            Get-ChildItem -Path $FolderPath -Filter *$EncryptionSuffix | ForEach-Object {
                $decryptFilePath = $_.FullName.TrimEnd($EncryptionSuffix)
                Write-Verbose -Message "Decrypting [$($_.FullName)] to [$($decryptFilePath)]"
                $startProcParams = @{
                    'FilePath'     = $GpgPath
                    'ArgumentList' = "--batch --yes --passphrase $Password -o $decryptFilePath -d $($_.FullName)"
                    'Wait'         = $true
                    'NoNewWindow'  = $true
                }
                $null = Start-Process @startProcParams
            }
            Get-ChildItem -Path $FolderPath | Where-Object {$_.Extension -ne $EncryptionSuffix}
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
}
function Remove-EncryptionFromFile {
    <#
	.SYNOPSIS
		This function decrypts a specific file. The key must exist in the secret keyring

	.PARAMETER FileName
		The full path to the encrypted *.gpg file. E.g. F:\MyFolder\MyFile.txt.gpg

	.PARAMETER Password
		The password for the secret key.


    .PARAMETER EncryptionSuffix
		The File extension of the files to be decrypted, e.g. .gpg or .pgp.


	.EXAMPLE
		PS> Remove-EncryptionFromFile -FileName F:\MyFolder\MyFile.txt.abc -Password VeryVerySecret

		This example will attempt to decrypt F:\MyFolder\MyFile.txt.abc to F:\MyFolder\MyFile.txt 
		using the password of 'VeryVerySecret'

	.INPUTS
		None. This function does not accept pipeline input.

	.OUTPUTS
		System.IO.FileInfo

	#>

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Password,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$GpgPath = 'C:\Program Files (x86)\GNU\GnuPG\gpg2.exe'

    )
    process {
        try {
            $EncryptionSuffix = [IO.Path]::GetExtension($FilePath)
            $decryptFilePath = $FilePath.TrimEnd($EncryptionSuffix)
                Write-Verbose -Message "Decrypting [$($FilePath)] to [$($decryptFilePath)]"
            $startProcParams = @{
                'FilePath'     = $GpgPath
                'ArgumentList' = "--batch --yes --passphrase $Password -o $decryptFilePath -d $FilePath"
                'Wait'         = $true
                'NoNewWindow'  = $true
            }
            $null = Start-Process @startProcParams
        }
        catch {
            Write-Error $_.Exception.Message
        }
    }
}
