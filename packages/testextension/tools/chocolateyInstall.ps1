param(
    $SomeString = "Initial Parameter Value"
)

Write-Host "This is the install script."
Write-Host "The value of `$SomeString is '$SomeString'"
Write-Host "The value of `$packageScript is '$packageScript'"

$PackageParameters = Get-PackageParameters

if ($PackageParameters.SomeString -ne $SomeString) {
    throw "'$SomeString' was not equal to '$($PackageParameters.SomeString)'"
}