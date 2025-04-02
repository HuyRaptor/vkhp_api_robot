*** Settings ***
Documentation     Complex End-to-End Test Suite for Warehouse Management with Inventory
...               Tests multi-warehouse coordination and product allocation
...               Includes operational constraints and cross-warehouse validation
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime

*** Variables ***
${BASE_URL}             https://api.vkho.net
${ADMIN_USERNAME}       huynh22
${ADMIN_PASSWORD}       Snowfox1991
${MANAGER_USERNAME}     huynh22.manager
${MANAGER_PASSWORD}     Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
@{TEST_WAREHOUSE_IDS}   ${EMPTY}
${TEST_ZONE_ID}         ${EMPTY}
${TEST_RACK_ID}         ${EMPTY}
${TEST_PRODUCT_ID}      ${EMPTY}
${MAX_PRODUCT_QUANTITY}  1000    # Total product units across all warehouses

*** Keywords ***
Setup Admin Session
    [Documentation]     Create API session and authenticate with admin credentials
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${ADMIN_USERNAME}    password=${ADMIN_PASSWORD}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${ADMIN_TOKEN}    ${token}
    Create Directory    ${RESULTS_DIR}

Setup Manager Session
    [Documentation]     Create API session and authenticate with manager credentials
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${MANAGER_USERNAME}    password=${MANAGER_PASSWORD}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${MANAGER_TOKEN}    ${token}

Generate Warehouse Data
    [Documentation]     Generate data for warehouse creation
    [Arguments]         ${suffix}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_data}=  Create Dictionary
    ...                 name=Inventory Warehouse ${suffix} ${timestamp}
    ...                 address=200 ${suffix} Road
    ...                 acreage=2000
    ...                 status=ENABLED
    RETURN            ${warehouse_data}

Generate Zone Data
    [Documentation]     Generate zone data
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${zone_data}=      Create Dictionary
    ...                 capacity=1000
    ...                 name=Inventory Zone ${timestamp}
    ...                 warehouseId=${warehouse_id}
    RETURN            ${zone_data}

Generate Rack Data
    [Documentation]     Generate rack data
    [Arguments]         ${warehouse_id}    ${zone_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${rack_data}=      Create Dictionary
    ...                 capacity=500
    ...                 warehouseId=${warehouse_id}
    ...                 zoneId=${zone_id}
    ...                 shelfId=1
    RETURN            ${rack_data}

Generate Product Data
    [Documentation]     Generate product data
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_data}=   Create Dictionary
    ...                 name=Test Product ${timestamp}
    ...                 sku=SKU-${timestamp}
    ...                 totalQuantity=${MAX_PRODUCT_QUANTITY}
    RETURN            ${product_data}

Create Warehouse
    [Documentation]     Create a new warehouse
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /warehouses/create
    ...                 json=${warehouse_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Zone
    [Documentation]     Create a new zone
    [Arguments]         ${zone_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /zones/create
    ...                 json=${zone_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Rack
    [Documentation]     Create a new rack
    [Arguments]         ${rack_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /racks/create
    ...                 json=${rack_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Create Product
    [Documentation]     Create a new product
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}[id]    ${json}

Allocate Product To Rack
    [Documentation]     Allocate product to a rack
    [Arguments]         ${rack_id}    ${product_id}    ${quantity}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${allocation_data}= Create Dictionary
    ...                 rackId=${rack_id}
    ...                 productId=${product_id}
    ...                 quantity=${quantity}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/allocate
    ...                 json=${allocation_data}
    ...                 headers=${headers}
    ...                 expected_status=any
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${response.status_code}    ${json}

Get Warehouse Inventory
    [Documentation]     Get warehouse inventory details
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /warehouses/${warehouse_id}/inventory
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    RETURN            ${json}

Delete Rack
    [Documentation]     Delete a rack
    [Arguments]         ${rack_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /racks/delete/${rack_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Zone
    [Documentation]     Delete a zone
    [Arguments]         ${zone_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /zones/delete/${zone_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Warehouse
    [Documentation]     Delete a warehouse
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${ADMIN_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Delete Product
    [Documentation]     Delete a product
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${MANAGER_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    RETURN            ${TRUE}

Validate Inventory Allocation
    [Documentation]     Validate product allocation across warehouses
    [Arguments]         ${inventory1}    ${inventory2}    ${product_id}    ${total_quantity}
    ${total_allocated}=    Evaluate    ${inventory1}[products][${product_id}][quantity] + ${inventory2}[products][${product_id}][quantity]
    Should Be Equal As Integers    ${total_allocated}    ${total_quantity}
    ...                            Total allocated quantity ${total_allocated} does not match expected ${total_quantity}

*** Test Cases ***
01 - Warehouse Inventory Management Flow
    [Documentation]     Test warehouse management with inventory and multi-warehouse coordination
    [Tags]              e2e    warehouse    inventory    multi-warehouse

    # Setup
    Setup Admin Session
    Setup Manager Session
    Log                 Authentication completed successfully

    # Step 1: Create Two Warehouses
    ${warehouse1_data}=    Generate Warehouse Data    Primary
    ${warehouse1_id}    ${warehouse1_response}=    Create Warehouse    ${warehouse1_data}
    Append To List    ${TEST_WAREHOUSE_IDS}    ${warehouse1_id}
    Log               Created primary warehouse: ${warehouse1_response}[name] with ID: ${warehouse1_id}

    ${warehouse2_data}=    Generate Warehouse Data    Secondary
    ${warehouse2_id}    ${warehouse2_response}=    Create Warehouse    ${warehouse2_data}
    Append To List    ${TEST_WAREHOUSE_IDS}    ${warehouse2_id}
    Log               Created secondary warehouse: ${warehouse2_response}[name] with ID: ${warehouse2_id}

    # Step 2: Create Zone and Rack in Primary Warehouse
    ${zone_data}=      Generate Zone Data    ${warehouse1_id}
    ${zone_id}    ${zone_response}=    Create Zone    ${zone_data}
    Set Global Variable  ${TEST_ZONE_ID}    ${zone_id}
    Log                 Created zone: ${zone_response}[name] with ID: ${zone_id}

    ${rack_data}=      Generate Rack Data    ${warehouse1_id}    ${zone_id}
    ${rack_id}    ${rack_response}=    Create Rack    ${rack_data}
    Set Global Variable  ${TEST_RACK_ID}    ${rack_id}
    Log                 Created rack with ID: ${rack_id}

    # Step 3: Create Product
    ${product_data}=   Generate Product Data
    ${product_id}    ${product_response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}    ${product_id}
    Should Be Equal As Integers    ${product_response}[totalQuantity]    ${MAX_PRODUCT_QUANTITY}
    Log                 Created product: ${product_response}[name] with ID: ${product_id}

    # Step 4: Allocate Product to Rack in Primary Warehouse
    ${status_a1}    ${allocation1_response}=    Allocate Product To Rack    ${rack_id}    ${product_id}    600
    Should Be Equal As Integers    ${status_a1}    201
    Should Be Equal As Integers    ${allocation1_response}[quantity]    600
    Log                 Allocated 600 units of product ${product_id} to rack ${rack_id}

    # Step 5: Attempt Allocation Exceeding Total Quantity
    ${status_a2}    ${allocation2_response}=    Allocate Product To Rack    ${rack_id}    ${product_id}    500
    Should Be Equal As Integers    ${status_a2}    400
    Should Contain    ${allocation2_response}[message]    quantity    ignore_case=True
    Log                 Successfully prevented allocation exceeding total product quantity

    # Step 6: Allocate Remaining Quantity to Secondary Warehouse Rack
    ${zone2_data}=     Generate Zone Data    ${warehouse2_id}
    ${zone2_id}    ${zone2_response}=    Create Zone    ${zone2_data}
    ${rack2_data}=     Generate Rack Data    ${warehouse2_id}    ${zone2_id}
    ${rack2_id}    ${rack2_response}=    Create Rack    ${rack2_data}

    ${status_a3}    ${allocation3_response}=    Allocate Product To Rack    ${rack2_id}    ${product_id}    400
    Should Be Equal As Integers    ${status_a3}    201
    Should Be Equal As Integers    ${allocation3_response}[quantity]    400
    Log                 Allocated 400 units of product ${product_id} to rack ${rack2_id}

    # Step 7: Validate Inventory Across Warehouses
    ${inventory1}=     Get Warehouse Inventory    ${warehouse1_id}
    ${inventory2}=     Get Warehouse Inventory    ${warehouse2_id}
    Validate Inventory Allocation    ${inventory1}    ${inventory2}    ${product_id}    ${MAX_PRODUCT_QUANTITY}
    Log                 Successfully validated product allocation across warehouses

    # Step 8: Clean Up
    Delete Rack    ${rack_id}
    Delete Rack    ${rack2_id}
    Delete Zone    ${TEST_ZONE_ID}
    Delete Zone    ${zone2_id}
    FOR    ${warehouse_id}    IN    @{TEST_WAREHOUSE_IDS}
        Delete Warehouse    ${warehouse_id}
    END
    Delete Product    ${TEST_PRODUCT_ID}
    Log                 Successfully cleaned up all resources