param(
    [Parameter(Mandatory = $true)]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$DatabasePath,

    [string]$PayloadBase64
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Decode-Base64Text {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

$ClientsTableName = Decode-Base64Text '0JrQu9GW0ZTQvdGC0Lg='
$BookingsTableName = Decode-Base64Text '0JHRgNC+0L3RjtCy0LDQvdC90Y8='

$ClientsTable = "[$ClientsTableName]"
$BookingsTable = "[$BookingsTableName]"

$ClientIdColumn = '[' + (Decode-Base64Text '0JrQu9GW0ZTQvdGCSUQ=') + ']'
$ClientFirstNameColumn = '[' + (Decode-Base64Text '0IbQvCfRjw==') + ']'
$ClientLastNameColumn = '[' + (Decode-Base64Text '0J/RgNGW0LfQstC40YnQtQ==') + ']'
$ClientPhoneColumn = '[' + (Decode-Base64Text '0KLQtdC70LXRhNC+0L0=') + ']'
$ClientEmailColumnName = Decode-Base64Text '0JXQu9C10LrRgtGA0L7QvdC90LDQn9C+0YjRgtCw'
$ClientEmailColumn = "[$ClientEmailColumnName]"
$ClientCreatedAtColumn = '[' + (Decode-Base64Text '0KHRgtCy0L7RgNC10L3Qvg==') + ']'
$ClientUpdatedAtColumn = '[' + (Decode-Base64Text '0J7QvdC+0LLQu9C10L3Qvg==') + ']'

$BookingIdColumn = '[' + (Decode-Base64Text '0JHRgNC+0L3RjtCy0LDQvdC90Y9JRA==') + ']'
$BookingClientIdColumn = '[' + (Decode-Base64Text '0JrQu9GW0ZTQvdGCSUQ=') + ']'
$BookingCheckInColumn = '[' + (Decode-Base64Text '0JTQsNGC0LDQl9Cw0ZfQt9C00YM=') + ']'
$BookingCheckOutColumn = '[' + (Decode-Base64Text '0JTQsNGC0LDQktC40ZfQt9C00YM=') + ']'
$BookingNightsColumn = '[' + (Decode-Base64Text '0JrRltC70YzQutGW0YHRgtGM0J3QvtGH0LXQuQ==') + ']'
$BookingRoomTypeColumn = '[' + (Decode-Base64Text '0KLQuNC/0JHRg9C00LjQvdC+0YfQutCw') + ']'
$BookingGuestsColumn = '[' + (Decode-Base64Text '0JrRltC70YzQutGW0YHRgtGM0JPQvtGB0YLQtdC5') + ']'
$BookingExtrasColumn = '[' + (Decode-Base64Text '0JTQvtC00LDRgtC60L7QstGW0J/QvtGB0LvRg9Cz0Lg=') + ']'
$BookingMessageColumn = '[' + (Decode-Base64Text '0J/QvtCx0LDQttCw0L3QvdGP') + ']'
$BookingTotalPriceColumn = '[' + (Decode-Base64Text '0JfQsNCz0LDQu9GM0L3QsNCS0LDRgNGC0ZbRgdGC0Yw=') + ']'
$BookingStatusColumn = '[' + (Decode-Base64Text '0KHRgtCw0YLRg9GB') + ']'
$BookingCreatedAtColumn = '[' + (Decode-Base64Text '0KHRgtCy0L7RgNC10L3Qvg==') + ']'

function Write-JsonResponse {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 6 -Compress
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    Write-Output $json
}

function New-DbConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $connection = New-Object -ComObject ADODB.Connection
    $connection.Open("Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$Path;")
    return $connection
}

function Test-TableExists {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        [string]$TableName
    )

    $schema = $Connection.OpenSchema(20)
    try {
        while (-not $schema.EOF) {
            $currentName = [string]$schema.Fields.Item('TABLE_NAME').Value
            if ($currentName -eq $TableName) {
                return $true
            }

            $schema.MoveNext()
        }

        return $false
    } finally {
        $schema.Close()
    }
}

function Test-ColumnExists {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        [string]$TableName,

        [Parameter(Mandatory = $true)]
        [string]$ColumnName
    )

    $columns = $Connection.OpenSchema(4, @($null, $null, $TableName, $null))
    try {
        while (-not $columns.EOF) {
            $currentName = [string]$columns.Fields.Item('COLUMN_NAME').Value
            if ($currentName -eq $ColumnName) {
                return $true
            }

            $columns.MoveNext()
        }

        return $false
    } finally {
        $columns.Close()
    }
}

function Test-ForeignKeyExists {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        [string]$PrimaryTableName,

        [Parameter(Mandatory = $true)]
        [string]$PrimaryColumnName,

        [Parameter(Mandatory = $true)]
        [string]$ForeignTableName,

        [Parameter(Mandatory = $true)]
        [string]$ForeignColumnName
    )

    $schema = $Connection.OpenSchema(27)
    try {
        while (-not $schema.EOF) {
            $pkTable = [string]$schema.Fields.Item('PK_TABLE_NAME').Value
            $pkColumn = [string]$schema.Fields.Item('PK_COLUMN_NAME').Value
            $fkTable = [string]$schema.Fields.Item('FK_TABLE_NAME').Value
            $fkColumn = [string]$schema.Fields.Item('FK_COLUMN_NAME').Value

            if (
                $pkTable -eq $PrimaryTableName -and
                $pkColumn -eq $PrimaryColumnName -and
                $fkTable -eq $ForeignTableName -and
                $fkColumn -eq $ForeignColumnName
            ) {
                return $true
            }

            $schema.MoveNext()
        }

        return $false
    } finally {
        $schema.Close()
    }
}

function Escape-SqlText {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    return $Value.Replace("'", "''").Trim()
}

function Format-SqlDate {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$Value
    )

    return '#' + $Value.ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) + '#'
}

function Format-SqlNumber {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value
    )

    return $Value.ToString([System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-TableRowCount {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        [string]$TableExpression
    )

    $recordset = $Connection.Execute("SELECT COUNT(*) AS TotalRows FROM $TableExpression")
    try {
        return [int]$recordset.Fields.Item('TotalRows').Value
    } finally {
        $recordset.Close()
    }
}

function Create-ClientsTable {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    $Connection.Execute(@"
CREATE TABLE $ClientsTable (
    $ClientIdColumn AUTOINCREMENT PRIMARY KEY,
    $ClientFirstNameColumn TEXT(100) NOT NULL,
    $ClientLastNameColumn TEXT(100) NOT NULL,
    $ClientPhoneColumn TEXT(30) NOT NULL,
    $ClientEmailColumn TEXT(150) NOT NULL,
    $ClientCreatedAtColumn DATETIME NOT NULL,
    $ClientUpdatedAtColumn DATETIME NOT NULL
)
"@) | Out-Null

    $Connection.Execute("CREATE INDEX idx_klienty_email ON $ClientsTable ($ClientEmailColumn)") | Out-Null
}

function Create-BookingsTable {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    $Connection.Execute(@"
CREATE TABLE $BookingsTable (
    $BookingIdColumn AUTOINCREMENT PRIMARY KEY,
    $BookingClientIdColumn LONG NOT NULL,
    $BookingCheckInColumn DATETIME NOT NULL,
    $BookingCheckOutColumn DATETIME NOT NULL,
    $BookingNightsColumn INTEGER NOT NULL,
    $BookingRoomTypeColumn TEXT(150) NOT NULL,
    $BookingGuestsColumn INTEGER NOT NULL,
    $BookingExtrasColumn MEMO,
    $BookingMessageColumn MEMO,
    $BookingTotalPriceColumn CURRENCY NOT NULL,
    $BookingStatusColumn TEXT(50) NOT NULL,
    $BookingCreatedAtColumn DATETIME NOT NULL
)
"@) | Out-Null

    $Connection.Execute("CREATE INDEX idx_broniuvannia_klient ON $BookingsTable ($BookingClientIdColumn)") | Out-Null
    $Connection.Execute("CREATE INDEX idx_broniuvannia_stvoreno ON $BookingsTable ($BookingCreatedAtColumn)") | Out-Null
}

function Ensure-BookingsRelationship {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    $clientIdColumnName = $ClientIdColumn.TrimStart('[').TrimEnd(']')
    $bookingClientIdColumnName = $BookingClientIdColumn.TrimStart('[').TrimEnd(']')

    if (Test-ForeignKeyExists -Connection $Connection -PrimaryTableName $ClientsTableName -PrimaryColumnName $clientIdColumnName -ForeignTableName $BookingsTableName -ForeignColumnName $bookingClientIdColumnName) {
        return
    }

    $Connection.Execute(
        "ALTER TABLE $BookingsTable ADD CONSTRAINT fk_broniuvannia_klienty FOREIGN KEY ($BookingClientIdColumn) REFERENCES $ClientsTable ($ClientIdColumn)"
    ) | Out-Null
}

function Migrate-EnglishSchema {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    $oldClientsExists = Test-TableExists -Connection $Connection -TableName 'Clients'
    $oldBookingsExists = Test-TableExists -Connection $Connection -TableName 'Bookings'

    if (-not $oldClientsExists -and -not $oldBookingsExists) {
        return
    }

    if (-not (Test-TableExists -Connection $Connection -TableName $ClientsTableName)) {
        Create-ClientsTable -Connection $Connection
    }

    if (-not (Test-TableExists -Connection $Connection -TableName $BookingsTableName)) {
        Create-BookingsTable -Connection $Connection
    }

    if ($oldClientsExists -and (Get-TableRowCount -Connection $Connection -TableExpression $ClientsTable) -eq 0) {
        $Connection.Execute(@"
INSERT INTO $ClientsTable (
    $ClientIdColumn,
    $ClientFirstNameColumn,
    $ClientLastNameColumn,
    $ClientPhoneColumn,
    $ClientEmailColumn,
    $ClientCreatedAtColumn,
    $ClientUpdatedAtColumn
)
SELECT
    ClientID,
    FirstName,
    LastName,
    Phone,
    Email,
    CreatedAt,
    UpdatedAt
FROM [Clients]
"@) | Out-Null
    }

    if ($oldBookingsExists -and (Get-TableRowCount -Connection $Connection -TableExpression $BookingsTable) -eq 0) {
        $Connection.Execute(@"
INSERT INTO $BookingsTable (
    $BookingIdColumn,
    $BookingClientIdColumn,
    $BookingCheckInColumn,
    $BookingCheckOutColumn,
    $BookingNightsColumn,
    $BookingRoomTypeColumn,
    $BookingGuestsColumn,
    $BookingExtrasColumn,
    $BookingMessageColumn,
    $BookingTotalPriceColumn,
    $BookingStatusColumn,
    $BookingCreatedAtColumn
)
SELECT
    BookingID,
    ClientID,
    CheckInDate,
    CheckOutDate,
    Nights,
    RoomType,
    Guests,
    Extras,
    Message,
    TotalPrice,
    Status,
    CreatedAt
FROM [Bookings]
"@) | Out-Null
    }

    if ($oldBookingsExists) {
        $Connection.Execute('DROP TABLE [Bookings]') | Out-Null
    }

    if ($oldClientsExists) {
        $Connection.Execute('DROP TABLE [Clients]') | Out-Null
    }
}

function Migrate-UkrainianSchemaRevision {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    if (-not (Test-TableExists -Connection $Connection -TableName $ClientsTableName)) {
        return
    }

    $legacyEmailExists = Test-ColumnExists -Connection $Connection -TableName $ClientsTableName -ColumnName 'Email'
    $newEmailExists = Test-ColumnExists -Connection $Connection -TableName $ClientsTableName -ColumnName $ClientEmailColumnName

    if (-not $legacyEmailExists -or $newEmailExists) {
        return
    }

    $tempClientsTableName = 'Clients_Temp_UA'
    $tempClientsTable = "[$tempClientsTableName]"

    if (Test-TableExists -Connection $Connection -TableName $tempClientsTableName) {
        $Connection.Execute("DROP TABLE $tempClientsTable") | Out-Null
    }

    $Connection.Execute(@"
CREATE TABLE $tempClientsTable (
    $ClientIdColumn LONG NOT NULL,
    $ClientFirstNameColumn TEXT(100) NOT NULL,
    $ClientLastNameColumn TEXT(100) NOT NULL,
    $ClientPhoneColumn TEXT(30) NOT NULL,
    $ClientEmailColumn TEXT(150) NOT NULL,
    $ClientCreatedAtColumn DATETIME NOT NULL,
    $ClientUpdatedAtColumn DATETIME NOT NULL
)
"@) | Out-Null

    $Connection.Execute(@"
INSERT INTO $tempClientsTable (
    $ClientIdColumn,
    $ClientFirstNameColumn,
    $ClientLastNameColumn,
    $ClientPhoneColumn,
    $ClientEmailColumn,
    $ClientCreatedAtColumn,
    $ClientUpdatedAtColumn
)
SELECT
    $ClientIdColumn,
    $ClientFirstNameColumn,
    $ClientLastNameColumn,
    $ClientPhoneColumn,
    [Email],
    $ClientCreatedAtColumn,
    $ClientUpdatedAtColumn
FROM $ClientsTable
"@) | Out-Null

    $Connection.Execute("DROP TABLE $ClientsTable") | Out-Null
    Create-ClientsTable -Connection $Connection

    $Connection.Execute(@"
INSERT INTO $ClientsTable (
    $ClientIdColumn,
    $ClientFirstNameColumn,
    $ClientLastNameColumn,
    $ClientPhoneColumn,
    $ClientEmailColumn,
    $ClientCreatedAtColumn,
    $ClientUpdatedAtColumn
)
SELECT
    $ClientIdColumn,
    $ClientFirstNameColumn,
    $ClientLastNameColumn,
    $ClientPhoneColumn,
    $ClientEmailColumn,
    $ClientCreatedAtColumn,
    $ClientUpdatedAtColumn
FROM $tempClientsTable
"@) | Out-Null

    $Connection.Execute("DROP TABLE $tempClientsTable") | Out-Null
}

function Initialize-Database {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

    Migrate-EnglishSchema -Connection $Connection
    Migrate-UkrainianSchemaRevision -Connection $Connection

    if (-not (Test-TableExists -Connection $Connection -TableName $ClientsTableName)) {
        Create-ClientsTable -Connection $Connection
    }

    if (-not (Test-TableExists -Connection $Connection -TableName $BookingsTableName)) {
        Create-BookingsTable -Connection $Connection
    }

    Ensure-BookingsRelationship -Connection $Connection
}

function Convert-FromPayload {
    param(
        [string]$Base64Value
    )

    if ([string]::IsNullOrWhiteSpace($Base64Value)) {
        return $null
    }

    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Base64Value))
    return $json | ConvertFrom-Json
}

function Get-ClientId {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        $Payload
    )

    $now = Get-Date
    $email = Escape-SqlText $Payload.email
    $firstName = Escape-SqlText $Payload.name
    $lastName = Escape-SqlText $Payload.surname
    $phone = Escape-SqlText $Payload.phone

    $recordset = $Connection.Execute("SELECT TOP 1 $ClientIdColumn AS ClientID FROM $ClientsTable WHERE $ClientEmailColumn = '$email'")
    try {
        if (-not $recordset.EOF) {
            $clientId = [int]$recordset.Fields.Item('ClientID').Value
            $Connection.Execute(
                "UPDATE $ClientsTable SET $ClientFirstNameColumn = '$firstName', $ClientLastNameColumn = '$lastName', $ClientPhoneColumn = '$phone', $ClientUpdatedAtColumn = $(Format-SqlDate $now) WHERE $ClientIdColumn = $clientId"
            ) | Out-Null
            return $clientId
        }
    } finally {
        $recordset.Close()
    }

    $Connection.Execute(
        "INSERT INTO $ClientsTable ($ClientFirstNameColumn, $ClientLastNameColumn, $ClientPhoneColumn, $ClientEmailColumn, $ClientCreatedAtColumn, $ClientUpdatedAtColumn) VALUES ('$firstName', '$lastName', '$phone', '$email', $(Format-SqlDate $now), $(Format-SqlDate $now))"
    ) | Out-Null

    $identity = $Connection.Execute('SELECT @@IDENTITY AS NewID')
    try {
        return [int]$identity.Fields.Item('NewID').Value
    } finally {
        $identity.Close()
    }
}

function Assert-BookingPayload {
    param(
        [Parameter(Mandatory = $true)]
        $Payload
    )

    $nameValue = [string]$Payload.PSObject.Properties.Item('name').Value
    $surnameValue = [string]$Payload.PSObject.Properties.Item('surname').Value
    $phoneValue = [string]$Payload.PSObject.Properties.Item('phone').Value
    $emailValue = [string]$Payload.PSObject.Properties.Item('email').Value
    $checkinValue = [string]$Payload.PSObject.Properties.Item('checkin').Value
    $checkoutValue = [string]$Payload.PSObject.Properties.Item('checkout').Value
    $guestsValue = [int]$Payload.PSObject.Properties.Item('guests').Value
    $totalPriceValue = [double]$Payload.PSObject.Properties.Item('totalPrice').Value

    $phoneDigits = $phoneValue -replace '\D', ''
    $emailPattern = '^[^\s@]+@[^\s@]+\.[^\s@]+$'

    if ([string]::IsNullOrWhiteSpace($nameValue) -or $nameValue.Trim().Length -lt 2) {
        throw 'Name is too short.'
    }

    if ([string]::IsNullOrWhiteSpace($surnameValue) -or $surnameValue.Trim().Length -lt 2) {
        throw 'Surname is too short.'
    }

    if ($phoneDigits.Length -lt 10) {
        throw 'Phone number is invalid.'
    }

    if ([string]::IsNullOrWhiteSpace($emailValue) -or ($emailValue -notmatch $emailPattern)) {
        throw 'Email address is invalid.'
    }

    if ([string]::IsNullOrWhiteSpace($checkinValue) -or [string]::IsNullOrWhiteSpace($checkoutValue)) {
        throw 'Check-in and check-out dates are required.'
    }

    $checkIn = [datetime]::Parse($checkinValue)
    $checkOut = [datetime]::Parse($checkoutValue)

    if ($checkOut -le $checkIn) {
        throw 'Check-out date must be later than check-in date.'
    }

    if ($guestsValue -lt 1) {
        throw 'Guests count is invalid.'
    }

    if ($totalPriceValue -lt 0) {
        throw 'Total price is invalid.'
    }
}

function Save-Booking {
    param(
        [Parameter(Mandatory = $true)]
        $Connection,

        [Parameter(Mandatory = $true)]
        $Payload
    )

    Assert-BookingPayload -Payload $Payload

    $clientId = Get-ClientId -Connection $Connection -Payload $Payload
    $now = Get-Date
    $checkIn = [datetime]::Parse([string]$Payload.checkin)
    $checkOut = [datetime]::Parse([string]$Payload.checkout)
    $nights = [math]::Max(1, ($checkOut.Date - $checkIn.Date).Days)
    $roomType = Escape-SqlText $Payload.roomType
    $extrasText = Escape-SqlText $Payload.extrasText
    $message = Escape-SqlText ([string]$Payload.message)
    $guests = [int]$Payload.guests
    $totalPrice = [double]$Payload.totalPrice
    $status = Decode-Base64Text '0J3QvtCy0LU='

    $Connection.Execute(
        "INSERT INTO $BookingsTable ($BookingClientIdColumn, $BookingCheckInColumn, $BookingCheckOutColumn, $BookingNightsColumn, $BookingRoomTypeColumn, $BookingGuestsColumn, $BookingExtrasColumn, $BookingMessageColumn, $BookingTotalPriceColumn, $BookingStatusColumn, $BookingCreatedAtColumn) VALUES ($clientId, $(Format-SqlDate $checkIn), $(Format-SqlDate $checkOut), $nights, '$roomType', $guests, '$extrasText', '$message', $(Format-SqlNumber $totalPrice), '$status', $(Format-SqlDate $now))"
    ) | Out-Null

    $identity = $Connection.Execute('SELECT @@IDENTITY AS NewID')
    try {
        $bookingId = [int]$identity.Fields.Item('NewID').Value
    } finally {
        $identity.Close()
    }

    return [pscustomobject]@{
        success = $true
        clientId = $clientId
        bookingId = $bookingId
    }
}

function Get-Bookings {
    param(
        [Parameter(Mandatory = $true)]
        $Connection
    )

$recordset = $Connection.Execute(@"
SELECT
    TOP 100
    b.$BookingIdColumn AS BookingID,
    c.$ClientFirstNameColumn AS FirstName,
    c.$ClientLastNameColumn AS LastName,
    c.$ClientPhoneColumn AS Phone,
    c.$ClientEmailColumn AS Email,
    b.$BookingCheckInColumn AS CheckInDate,
    b.$BookingCheckOutColumn AS CheckOutDate,
    b.$BookingNightsColumn AS Nights,
    b.$BookingRoomTypeColumn AS RoomType,
    b.$BookingGuestsColumn AS Guests,
    b.$BookingExtrasColumn AS Extras,
    b.$BookingMessageColumn AS Message,
    b.$BookingTotalPriceColumn AS TotalPrice,
    b.$BookingStatusColumn AS Status,
    b.$BookingCreatedAtColumn AS CreatedAt
FROM $BookingsTable AS b
INNER JOIN $ClientsTable AS c ON c.$ClientIdColumn = b.$BookingClientIdColumn
ORDER BY b.$BookingCreatedAtColumn DESC
"@)

    $rows = @()

    try {
        while (-not $recordset.EOF) {
            $rows += [pscustomobject]@{
                bookingId = [int]$recordset.Fields.Item('BookingID').Value
                firstName = [string]$recordset.Fields.Item('FirstName').Value
                lastName = [string]$recordset.Fields.Item('LastName').Value
                phone = [string]$recordset.Fields.Item('Phone').Value
                email = [string]$recordset.Fields.Item('Email').Value
                checkInDate = [datetime]$recordset.Fields.Item('CheckInDate').Value
                checkOutDate = [datetime]$recordset.Fields.Item('CheckOutDate').Value
                nights = [int]$recordset.Fields.Item('Nights').Value
                roomType = [string]$recordset.Fields.Item('RoomType').Value
                guests = [int]$recordset.Fields.Item('Guests').Value
                extras = [string]$recordset.Fields.Item('Extras').Value
                message = [string]$recordset.Fields.Item('Message').Value
                totalPrice = [decimal]$recordset.Fields.Item('TotalPrice').Value
                status = [string]$recordset.Fields.Item('Status').Value
                createdAt = [datetime]$recordset.Fields.Item('CreatedAt').Value
            }

            $recordset.MoveNext()
        }
    } finally {
        $recordset.Close()
    }

    return [pscustomobject]@{
        success = $true
        bookings = $rows
    }
}

if (-not (Test-Path -LiteralPath $DatabasePath)) {
    throw "Database file not found: $DatabasePath"
}

$connection = New-DbConnection -Path $DatabasePath

try {
    Initialize-Database -Connection $connection

    switch ($Action) {
        'init' {
            Write-JsonResponse @{
                success = $true
                message = Decode-Base64Text '0JHQsNC30YMg0LTQsNC90LjRhSDQv9GW0LTQs9C+0YLQvtCy0LvQtdC90L4u'
            }
        }
        'save-booking' {
            $payload = Convert-FromPayload -Base64Value $PayloadBase64
            Write-JsonResponse (Save-Booking -Connection $connection -Payload $payload)
        }
        'list-bookings' {
            Write-JsonResponse (Get-Bookings -Connection $connection)
        }
        default {
            throw "Unsupported action: $Action"
        }
    }
} finally {
    $connection.Close()
}
