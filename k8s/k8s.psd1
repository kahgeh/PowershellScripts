#
# Module manifest for module 'manifest'
#
# Generated by: kahgeh.tan
#
# Generated on: 15/10/19
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'k8s'

    # Version number of this module.
    ModuleVersion     = '0.0.1'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = '88f874c8-4630-4048-9fdc-fc1f0494e516'

    # Author of this module
    Author            = 'kahgeh@hotmail.com'

    # Company or vendor of this module
    CompanyName       = '10kg'

    # Copyright statement for this module
    Copyright         = '(c) 10kg. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = ''

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '6.0'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Save-SecretsMetaDataFile', 
        'Get-PublishedSecrets', 
        'Publish-Secrets'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            # ProjectUri = ''

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

