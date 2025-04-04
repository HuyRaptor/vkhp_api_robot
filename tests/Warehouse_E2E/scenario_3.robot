*** Settings ***
Documentation     End-to-End Test Suite for Warehouse Management Workflow
...               Tests complete flow from warehouse creation to rack management
...               Validates relationships between warehouse, zones, and racks
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Resource          ../../Variables/variables.robot

*** Keywords ***
Setup Admin Session
    [Documentation]     Create API session and authenticate with admin credentials
    Create Session      vkho_admin        ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho_admin
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${ADMIN_TOKEN}    ${token}
    
    Create Directory    ${RESULTS_DIR}

Setup Manager Session
    [Documentation]     Create API session and authenticate with manager credentials
    Create Session      vkho_manager      ${BASE_URL}      verify=True    disable_warnings=True
    
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    
    ${response}=        POST On Session
    ...                 vkho_manager
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Warehouse Data
    [Documentation]     Generate data for warehouse creation
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=E2E Warehouse ${timestamp}
    ...                 address=789 Logistics Ave
    ...                 acreage=2000
    RETURN              ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate data for zone creation
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=       Create Dictionary
    ...                 capcity=1000
    ...                 name=Storage Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN              ${zone_data}

Generate Rack Data
    [Documentation]     Generate data for rack creation
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=       Create Dictionary
    ...                 capacity=200
    ...                 warehouseId=${warehouse_id}
    ...                 shelfId=1
    RETURN              ${rack_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${warehouse_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${warehouse_data}    address
    ...    msg=Missing required parameter: address
    Dictionary Should Contain Key    ${warehouse_data}    acreage
    ...    msg=Missing required parameter: acreage
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        POST On Session
    ...                 vkho_admin
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create warehouse response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Create warehouse response missing ID field
    
    RETURN              ${json}[id]    ${json}

Create Zone
    [Documentation]     Create a new zone
    [Arguments]         ${zone_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${zone_data}    name
    ...    msg=Missing required parameter: name
    Dictionary Should Contain Key    ${zone_data}    capcity
    ...    msg=Missing required parameter: capcity
    Dictionary Should Contain Key    ${zone_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho_manager
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create zone response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Create zone response missing ID field
    
    RETURN              ${json}[id]    ${json}

Create Rack
    [Documentation]     Create a new rack
    [Arguments]         ${rack_data}
    
    # Validate required parameters
    Dictionary Should Contain Key    ${rack_data}    capacity
    ...    msg=Missing required parameter: capacity
    Dictionary Should Contain Key    ${rack_data}    warehouseId
    ...    msg=Missing required parameter: warehouseId
    Dictionary Should Contain Key    ${rack_data}    shelfId
    ...    msg=Missing required parameter: shelfId
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho_manager
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Create rack response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Create rack response missing ID field
    
    RETURN              ${json}[id]    ${json}

Get Warehouse Details
    [Documentation]     Get warehouse details
    [Arguments]         ${warehouse_id}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        GET On Session
    ...                 vkho_admin
    ...                 /warehouses/get-one/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get warehouse response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Get warehouse response missing ID field
    
    RETURN              ${json}

Get Zone Details
    [Documentation]     Get zone details
    [Arguments]         ${zone_id}
    
    # Validate parameters
    Should Not Be Empty    ${zone_id}
    ...    msg=Zone ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session
    ...                 vkho_manager
    ...                 /zones/get-one/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get zone response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Get zone response missing ID field
    
    RETURN              ${json}

Get Rack Details
    [Documentation]     Get rack details
    [Arguments]         ${rack_id}
    
    # Validate parameters
    Should Not Be Empty    ${rack_id}
    ...    msg=Rack ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        GET On Session
    ...                 vkho_manager
    ...                 /racks/get-one/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Get rack response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Get rack response missing ID field
    
    RETURN              ${json}

Update Rack Capacity
    [Documentation]     Update rack capacity
    [Arguments]         ${rack_id}    ${new_capacity}
    
    # Validate parameters
    Should Not Be Empty    ${rack_id}
    ...    msg=Rack ID cannot be empty
    
    # First get the current rack details to preserve other fields
    ${rack}=            Get Rack Details    ${rack_id}
    
    # Prepare update data
    ${update_data}=     Create Dictionary
    ...                 id=${rack_id}
    ...                 capacity=${new_capacity}
    ...                 warehouseId=${rack}[warehouseId]
    ...                 shelfId=${rack}[shelfId]
    ...                 status=ENABLE
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho_manager
    ...                 /racks/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Process response
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Should Not Be Empty    ${json}
    ...    msg=Update rack response was empty
    Dictionary Should Contain Key    ${json}    id
    ...    msg=Update rack response missing ID field
    
    RETURN              ${json}

Delete Rack
    [Documentation]     Delete a rack
    [Arguments]         ${rack_id}
    
    # Validate parameters
    Should Not Be Empty    ${rack_id}
    ...    msg=Rack ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho_manager
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Verify deletion
    ${verification}=    Run Keyword And Return Status
    ...                 Run Keyword And Expect Error    *
    ...                 Get Rack Details    ${rack_id}
    
    RETURN              ${verification}

Delete Zone
    [Documentation]     Delete a zone
    [Arguments]         ${zone_id}
    
    # Validate parameters
    Should Not Be Empty    ${zone_id}
    ...    msg=Zone ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho_manager
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Verify deletion
    ${verification}=    Run Keyword And Return Status
    ...                 Run Keyword And Expect Error    *
    ...                 Get Zone Details    ${zone_id}
    
    RETURN              ${verification}

Delete Warehouse
    [Documentation]     Delete a warehouse
    [Arguments]         ${warehouse_id}
    
    # Validate parameters
    Should Not Be Empty    ${warehouse_id}
    ...    msg=Warehouse ID cannot be empty
    
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho_admin
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    
    # Verify deletion
    ${verification}=    Run Keyword And Return Status
    ...                 Run Keyword And Expect Error    *
    ...                 Get Warehouse Details    ${warehouse_id}
    
    RETURN              ${verification}

Verify Zone Belongs To Warehouse
    [Documentation]     Verify zone belongs to warehouse
    [Arguments]         ${zone}    ${warehouse_id}
    
    Should Be Equal As Strings    ${zone}[warehouseId]    ${warehouse_id}
    ...    msg=Zone does not belong to expected warehouse

Verify Rack Belongs To Warehouse
    [Documentation]     Verify rack belongs to warehouse
    [Arguments]         ${rack}    ${warehouse_id}
    
    Should Be Equal As Strings    ${rack}[warehouseId]    ${warehouse_id}
    ...    msg=Rack does not belong to expected warehouse

*** Test Cases ***
01 - Warehouse Management End-to-End Flow
    [Documentation]     Test complete warehouse management workflow
    [Tags]              e2e    warehouse    zone    rack

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Warehouse
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Should Be Equal     ${warehouse_response}[name]    ${warehouse_data}[name]
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_id}

    # Step 2: Create Zone in Warehouse
    ${zone_data}=       Generate Zone Data    ${warehouse_id}
    ${zone_id}    ${zone_response}=    Create Zone    ${zone_data}
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_id}
    Should Be Equal     ${zone_response}[warehouseId]    ${warehouse_id}
    Log                 Created zone: ${zone_response}[name] with ID: ${zone_id}

    # Step 3: Create Rack in Warehouse
    ${rack_data}=       Generate Rack Data    ${warehouse_id}
    ${rack_id}    ${rack_response}=    Create Rack    ${rack_data}
    Set Global Variable  ${TEST_RACK_ID}    ${rack_id}
    Should Be Equal     ${rack_response}[warehouseId]    ${warehouse_id}
    Log                 Created rack with ID: ${rack_id}

    # Step 4: Verify Structure Relationships
    ${warehouse_details}=    Get Warehouse Details    ${warehouse_id}
    ${zone_details}=         Get Zone Details         ${zone_id}
    ${rack_details}=         Get Rack Details         ${rack_id}
    
    # Verify zone belongs to warehouse
    Verify Zone Belongs To Warehouse    ${zone_details}    ${warehouse_id}
    
    # Verify rack belongs to warehouse
    Verify Rack Belongs To Warehouse    ${rack_details}    ${warehouse_id}
    
    Log                 Successfully verified warehouse structure relationships

    # Step 5: Update Rack Capacity
    ${updated_rack}=    Update Rack Capacity    ${rack_id}    300
    Should Be Equal As Integers    ${updated_rack}[capacity]    300
    Log                 Updated rack capacity to 300

    # Step 6: Clean Up
    ${rack_deleted}=    Delete Rack    ${rack_id}
    Should Be True      ${rack_deleted}
    Log                 Successfully deleted rack with ID: ${rack_id}
    
    ${zone_deleted}=    Delete Zone    ${zone_id}
    Should Be True      ${zone_deleted}
    Log                 Successfully deleted zone with ID: ${zone_id}
    
    ${warehouse_deleted}=    Delete Warehouse    ${warehouse_id}
    Should Be True      ${warehouse_deleted}
    Log                 Successfully deleted warehouse with ID: ${warehouse_id}
    
    Log                 Successfully completed end-to-end warehouse management workflow test

02 - Verify Warehouse Creation And Management
    [Documentation]     Test warehouse creation and verify its management capabilities
    [Tags]              e2e    warehouse

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Warehouse
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_data}[name]=    Set Variable    Specialized Warehouse ${Evaluate}    int(time.time())    time
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Should Be Equal     ${warehouse_response}[name]    ${warehouse_data}[name]
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_id}

    # Step 2: Get Warehouse Details
    ${warehouse_details}=    Get Warehouse Details    ${warehouse_id}
    Should Be Equal     ${warehouse_details}[name]    ${warehouse_data}[name]
    Should Be Equal     ${warehouse_details}[address]    ${warehouse_data}[address]
    Should Be Equal     ${warehouse_details}[acreage]    ${warehouse_data}[acreage]
    Log                 Successfully retrieved and verified warehouse details

    # Step 3: Clean Up
    ${warehouse_deleted}=    Delete Warehouse    ${warehouse_id}
    Should Be True      ${warehouse_deleted}
    Log                 Successfully deleted warehouse with ID: ${warehouse_id}

03 - Verify Zone Management
    [Documentation]     Test zone creation and management within a warehouse
    [Tags]              e2e    zone

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Warehouse
    ${warehouse_data}=  Generate Warehouse Data
    ${warehouse_id}    ${warehouse_response}=    Create Warehouse    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Log                 Created warehouse: ${warehouse_response}[name] with ID: ${warehouse_id}

    # Step 2: Create Multiple Zones
    ${zone_data_1}=     Generate Zone Data    ${warehouse_id}
    ${zone_data_1}[name]=    Set Variable    Primary Zone ${Evaluate}    int(time.time())    time
    ${zone_id_1}    ${zone_response_1}=    Create Zone    ${zone_data_1}
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_id_1}
    Log                 Created first zone: ${zone_response_1}[name] with ID: ${zone_id_1}
    
    ${zone_data_2}=     Generate Zone Data    ${warehouse_id}
    ${zone_data_2}[name]=    Set Variable    Secondary Zone ${Evaluate}    int(time.time())    time
    ${zone_id_2}    ${zone_response_2}=    Create Zone    ${zone_data_2}
    Log                 Created second zone: ${zone_response_2}[name] with ID: ${zone_id_2}
    
    # Step 3: Verify Zone Details
    ${zone_details_1}=  Get Zone Details    ${zone_id_1}
    ${zone_details_2}=  Get Zone Details    ${zone_id_2}
    
    Should Be Equal     ${zone_details_1}[name]    ${zone_data_1}[name]
    Should Be Equal     ${zone_details_1}[warehouseId]    ${warehouse_id}
    
    Should Be Equal     ${zone_details_2}[name]    ${zone_data_2}[name]
    Should Be Equal     ${zone_details_2}[warehouseId]    ${warehouse_id}
    
    Log                 Successfully verified zone details

    # Step 4: Clean Up
    ${zone_deleted_1}=  Delete Zone    ${zone_id_1}
    ${zone_deleted_2}=  Delete Zone    ${zone_id_2}
    ${warehouse_deleted}=    Delete Warehouse    ${warehouse_id}
    
    Should Be True      ${zone_deleted_1}
    Should Be True      ${zone_deleted_2}
    Should Be True      ${warehouse_deleted}
    
    Log                 Successfully cleaned up all resources