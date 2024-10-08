﻿function New-HTMLGroupOfDiagramDefault {
    <#
    .SYNOPSIS
    Creates a default HTML group diagram with specified parameters.

    .DESCRIPTION
    This function creates a default HTML group diagram with the ability to customize various display options.

    .PARAMETER Identity
    Specifies an array of objects to be included in the diagram.

    .PARAMETER HideAppliesTo
    Specifies whether to hide elements based on their type. Valid values are 'Default', 'Hierarchical', or 'Both'. Default is 'Both'.

    .PARAMETER HideComputers
    Indicates whether to hide computer objects in the diagram.

    .PARAMETER HideUsers
    Indicates whether to hide user objects in the diagram.

    .PARAMETER HideOther
    Indicates whether to hide other types of objects in the diagram.

    .PARAMETER DataTableID
    Specifies the ID of the data table associated with the diagram.

    .PARAMETER ColumnID
    Specifies the ID of the column associated with the data table.

    .PARAMETER Online
    Indicates whether to display objects as online in the diagram.

    .EXAMPLE
    New-HTMLGroupOfDiagramDefault -Identity $ADObjects -HideUsers -DataTableID "DataTable1" -ColumnID 1 -Online
    Creates a default HTML group diagram with Active Directory objects, hides user objects, associates it with DataTable1, and displays objects as online.

    .EXAMPLE
    New-HTMLGroupOfDiagramDefault -Identity $ADObjects -HideComputers -HideAppliesTo 'Hierarchical'
    Creates a default HTML group diagram with Active Directory objects, hides computer objects, and only displays elements based on the hierarchical setting.

    #>
    [cmdletBinding()]
    param(
        [Array] $Identity,
        [ValidateSet('Default', 'Hierarchical', 'Both')][string] $HideAppliesTo = 'Both',
        [switch] $HideComputers,
        [switch] $HideUsers,
        [switch] $HideOther,
        [string] $DataTableID,
        [int] $ColumnID,
        [switch] $Online,
        [switch] $EnableDiagramFiltering,
        [switch] $EnableDiagramFilteringButton,
        [int] $DiagramFilteringMinimumCharacters = 3
    )
    New-HTMLDiagram -Height 'calc(100vh - 200px)' {
        #if ($DataTableID) {
        #    New-DiagramEvent -ID $DataTableID -ColumnID $ColumnID
        #}
        #New-DiagramOptionsLayout -HierarchicalEnabled $true -HierarchicalDirection FromLeftToRight #-HierarchicalSortMethod directed
        #New-DiagramOptionsPhysics -Enabled $true -HierarchicalRepulsionAvoidOverlap 1 -HierarchicalRepulsionNodeDistance 50
        New-DiagramOptionsPhysics -RepulsionNodeDistance 150 -Solver repulsion
        if ($Identity) {
            # Add it's members to diagram
            foreach ($ADObject in $Identity) {
                # Lets build our diagram
                #[int] $Level = $($ADObject.Nesting) + 1
                $ID = "$($ADObject.DomainName)$($ADObject.DistinguishedName)"
                #[int] $LevelParent = $($ADObject.Nesting)
                $IDParent = "$($ADObject.ParentGroupDomain)$($ADObject.ParentGroupDN)"

                if ($ADObject.Type -eq 'User') {
                    if (-not $HideUsers -or $HideAppliesTo -notin 'Both', 'Default') {
                        $Label = $ADObject.Name + [System.Environment]::NewLine + $ADObject.DomainName
                        if ($Online) {
                            New-DiagramNode -Id $ID -Label $Label -Image $Script:ConfigurationIcons.ImageUser
                        } else {
                            New-DiagramNode -Id $ID -Label $Label -IconSolid user -IconColor LightSteelBlue
                        }
                        New-DiagramLink -ColorOpacity 0.2 -From $ID -To $IDParent -Color Blue -ArrowsFromEnabled -Dashes
                    }
                } elseif ($ADObject.Type -eq 'Group') {
                    if ($ADObject.Nesting -eq -1) {
                        $BorderColor = 'Red'
                        $Image = $Script:ConfigurationIcons.ImageGroup
                    } else {
                        $BorderColor = 'Blue'
                        $Image = $Script:ConfigurationIcons.ImageGroupNested
                    }
                    #$SummaryMembers = -join ('Total: ', $ADObject.TotalMembers, ' Direct: ', $ADObject.DirectMembers, ' Groups: ', $ADObject.DirectGroups, ' Indirect: ', $ADObject.IndirectMembers)
                    $Label = $ADObject.Name + [System.Environment]::NewLine + $ADObject.DomainName + [System.Environment]::NewLine #+ $SummaryMembers
                    if ($Online) {
                        New-DiagramNode -Id $ID -Label $Label -Image $Image -ColorBorder $BorderColor
                    } else {
                        New-DiagramNode -Id $ID -Label $Label -IconSolid user-friends -IconColor VeryLightGrey
                    }
                    New-DiagramLink -ColorOpacity 0.5 -From $ID -To $IDParent -Color Orange -ArrowsFromEnabled
                } elseif ($ADObject.Type -eq 'Computer') {
                    if (-not $HideComputers -or $HideAppliesTo -notin 'Both', 'Default') {
                        $Label = $ADObject.Name + [System.Environment]::NewLine + $ADObject.DomainName
                        if ($Online) {
                            New-DiagramNode -Id $ID -Label $Label -Image $Script:ConfigurationIcons.ImageComputer
                        } else {
                            New-DiagramNode -Id $ID -Label $Label -IconSolid desktop -IconColor LightGray
                        }
                        New-DiagramLink -ColorOpacity 0.2 -From $ID -To $IDParent -Color Arsenic -ArrowsFromEnabled -Dashes
                    }
                } else {
                    if (-not $HideOther -or $HideAppliesTo -notin 'Both', 'Default') {
                        $Label = $ADObject.Name + [System.Environment]::NewLine + $ADObject.DomainName
                        if ($Online) {
                            New-DiagramNode -Id $ID -Label $Label -Image $Script:ConfigurationIcons.ImageOther
                        } else {
                            New-DiagramNode -Id $ID -Label $Label -IconSolid robot -IconColor LightSalmon
                        }
                        New-DiagramLink -ColorOpacity 0.2 -From $ID -To $IDParent -Color Boulder -ArrowsFromEnabled -Dashes
                    }
                }
            }
        }
    } -EnableFiltering:$EnableDiagramFiltering.IsPresent -MinimumFilteringChars $DiagramFilteringMinimumCharacters -EnableFilteringButton:$EnableDiagramFilteringButton.IsPresent
}