*** Settings ***
Documentation     End-to-End Test Suite for vKho Inventory Adjustment and Auditing
...               Covers inventory creation, stock adjustments, and audit logging
...               Includes positive, negative, edge, concurrency, and validation tests
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           Process
Resource          ../../Variables/variables.robot
Suite Setup       Setup Test Suite
Suite Teardown    Teardown Test Suite

*** Keywords ***
Setup Test Suite
    [Documentation]     Initialize suite-level variables and session
    Setup API Session
    ${START_TIME}=      Get Current Date    result_format=epoch
    Set Suite Variable  ${START_TIME}
    Create Directory    ${RESULTS_DIR}
    File Should Not Exist    ${SUMMARY_FILE}
    Write Summary Header
    # Setup foundational entities
    ${warehouse_data}=  Generate Unique Warehouse Data
    ${warehouse_id}    ${w_response}=    Create Warehouse With Retry    ${warehouse_data}
    Set Global Variable  ${TEST_WAREHOUSE_ID}    ${warehouse_id}
    Set Global Variable  ${TEST_WAREHOUSE_NAME}  ${warehouse_data}[name]
    ${product_data}=    Generate Unique Product Data    ${warehouse_id}
    ${product_id}    ${p_response}=    Create Product    ${product_data}
    Set Global Variable  ${TEST_PRODUCT_ID}      ${product_id}
    Set Global Variable  ${TEST_PRODUCT_NAME}    ${product_data}[name]

Teardown Test Suite
    [Documentation]     Clean up all created resources and log suite metrics
    Run Keyword If      "${TEST_ADJUSTMENT_ID}" != "${EMPTY}"    Delete Adjustment    ${TEST_ADJUSTMENT_ID}
    Run Keyword If      "${TEST_INVENTORY_ID}" != "${EMPTY}"    Delete Inventory    ${TEST_INVENTORY_ID}
    Run Keyword If      "${TEST_PRODUCT_ID}" != "${EMPTY}"    Delete Product    ${TEST_PRODUCT_ID}
    Run Keyword If      "${TEST_WAREHOUSE_ID}" != "${EMPTY}"    Delete Warehouse    ${TEST_WAREHOUSE_ID}
    ${end_time}=        Get Current Date    result_format=epoch
    ${duration}=        Evaluate    ${end_time} - ${START_TIME}
    ${avg_time}=        Evaluate    ${duration} / ${OPERATION_COUNT} if ${OPERATION_COUNT} > 0 else 0
    Log                 Suite completed in ${duration} seconds with ${OPERATION_COUNT} API operations (avg ${avg_time}s per operation)
    Write Summary Footer    ${duration}    ${OPERATION_COUNT}    ${avg_time}

Setup API Session
    [Documentation]     Create API session and authenticate
    Create Session      vkho             ${BASE_URL}      verify=True    disable_warnings=True
    ${headers}=         Create Dictionary    Content-Type=application/json
    ${body}=            Create Dictionary    username=${USERNAME}    password=${PASSWORD}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /auth/login
    ...                 json=${body}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Dictionary Should Contain Key        ${json}    access_token
    ${token}=           Set Variable     Bearer ${json}[access_token]
    Set Global Variable  ${AUTH_TOKEN}    ${token}
    Increment Operation Count

Generate Unique Warehouse Data
    [Documentation]     Generate unique data for warehouse tests
    ${timestamp}=       Evaluate         int(time.time())    time
    ${warehouse_name}=  Set Variable     Inventory Warehouse ${timestamp}
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 address=456 Inventory Lane
    ...                 acreage=1000
    RETURN            ${warehouse_data}

Generate Unique Product Data
    [Documentation]     Generate unique data for product tests
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${product_name}=    Set Variable     Inventory Product ${timestamp}
    ${product_data}=    Create Dictionary
    ...                 name=${product_name}
    ...                 totalQuantity=100
    ...                 expectedQuantity=100
    ...                 importDate=2025-04-01T00:00:00.000Z
    ...                 cost=10
    ...                 salePrice=15
    ...                 warehouseId=${warehouse_id}
    ...                 inboundKind=NEW
    ...                 expireDate=2026-04-01T00:00:00.000Z
    ...                 productCode=INV${timestamp}
    ...                 supplierId=1    # Assuming a default supplier exists
    ...                 productCategoryId=1
    ...                 rackId=1
    ...                 barCode=BAR${timestamp}
    RETURN            ${product_data}

Generate Inventory Data
    [Documentation]     Generate data for inventory creation
    [Arguments]         ${warehouse_id}    ${product_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${inventory_data}=  Create Dictionary
    ...                 warehouseId=${warehouse_id}
    ...                 productId=${product_id}
    ...                 currentQuantity=100
    ...                 lastUpdated=2025-04-01T00:00:00.000Z
    ...                 status=ACTIVE
    ...                 note=Initial inventory ${timestamp}
    RETURN            ${inventory_data}

Generate Adjustment Data
    [Documentation]     Generate data for stock adjustment
    [Arguments]         ${inventory_id}    ${quantity_change}    ${reason}=STOCK_ADJUSTMENT
    ${timestamp}=       Evaluate         int(time.time())    time
    ${adjustment_data}= Create Dictionary
    ...                 inventoryId=${inventory_id}
    ...                 quantityChange=${quantity_change}
    ...                 reason=${reason}
    ...                 adjustmentDate=2025-04-01T00:00:00.000Z
    ...                 note=Adjustment ${timestamp}
    RETURN            ${adjustment_data}

Create Warehouse With Retry
    [Documentation]     Create a new warehouse with retry logic
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${attempt}=         Set Variable    1
    FOR    ${attempt}    IN RANGE    1    ${MAX_RETRIES + 1}
    \    ${response}=    Run Keyword And Ignore Error
    \    ...             POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=anything
    \    ${status}=      Set Variable If    "${response[0]}" == "PASS"    ${response[1].status_code}    500
    \    Exit For Loop If    ${status} == 201
    \    Sleep           ${RETRY_DELAY}
    \    Run Keyword If  ${attempt} == ${MAX_RETRIES}    Fail    Failed to create warehouse after ${MAX_RETRIES} attempts
    END
    ${json}=            Evaluate         json.loads('''${response[1].text}''')    json
    ${warehouse_id}=    Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${warehouse_id}    ${response[1]}

Create Product
    [Documentation]     Create a new product and return its ID
    [Arguments]         ${product_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /products/create
    ...                 json=${product_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${product_id}=      Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${product_id}    ${response}

Create Inventory
    [Documentation]     Create a new inventory record
    [Arguments]         ${inventory_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/create
    ...                 json=${inventory_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${inventory_id}=    Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${inventory_id}    ${response}

Adjust Inventory
    [Documentation]     Adjust stock levels in an inventory record
    [Arguments]         ${adjustment_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/adjust
    ...                 json=${adjustment_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${adjustment_id}=   Convert To String    ${json}[id]
    Increment Operation Count
    RETURN            ${adjustment_id}    ${response}

Get Inventory By ID
    [Documentation]     Retrieve an inventory record by ID
    [Arguments]         ${inventory_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /inventory/get-one/${inventory_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Get Adjustment History
    [Documentation]     Retrieve adjustment history for an inventory record
    [Arguments]         ${inventory_id}    ${page}=1    ${size}=${PAGE_SIZE}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${params}=          Create Dictionary    page=${page}    size=${size}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /inventory/${inventory_id}/adjustments
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    RETURN            ${response}

Delete Warehouse
    [Documentation]     Delete a warehouse from the system
    [Arguments]         ${warehouse_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /warehouses/delete/${warehouse_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Delete Product
    [Documentation]     Delete a product from the system
    [Arguments]         ${product_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /products/delete/${product_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Delete Inventory
    [Documentation]     Delete an inventory record from the system
    [Arguments]         ${inventory_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /inventory/delete/${inventory_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    RETURN            ${TRUE}

Delete Adjustment
    [Documentation]     Delete an adjustment record (if supported)
    [Arguments]         ${adjustment_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /inventory/adjustments/delete/${adjustment_id}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Increment Operation Count
    RETURN            ${response.status_code} == 200

Assert Inventory Details
    [Documentation]     Verify inventory details match expected values
    [Arguments]         ${inventory}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${inventory}    Should Be Equal    ${inventory}[${key}]    ${expected_data}[${key}]
        ...    msg=Inventory ${key} value '${inventory}[${key}]' does not match expected '${expected_data}[${key}]'
    END

Log Response Details
    [Documentation]     Log detailed response information
    [Arguments]         ${response}    ${entity_type}
    ${status}=          Convert To String    ${response.status_code}
    ${body}=            Set Variable If    ${response.text}    ${response.text}    "No body"
    ${elapsed}=         Convert To String    ${response.elapsed.total_seconds()}
    Log                 ${entity_type} Response - Status: ${status}, Body: ${body}, Time: ${elapsed}s

Increment Operation Count
    [Documentation]     Increment the count of API operations performed
    ${OPERATION_COUNT}=  Evaluate    ${OPERATION_COUNT} + 1
    Set Global Variable  ${OPERATION_COUNT}

Write Summary Header
    [Documentation]     Write the header for the test summary file
    ${header}=          Set Variable    Inventory Test Summary Report\n==================\nTest Name\tDuration (s)\n
    Create File         ${SUMMARY_FILE}    ${header}

Append To Summary
    [Documentation]     Append a test result to the summary file
    [Arguments]         ${test_name}    ${duration}
    ${line}=            Set Variable    ${test_name}\t${duration}\n
    Append To File      ${SUMMARY_FILE}    ${line}

Write Summary Footer
    [Documentation]     Write the footer with total metrics to the summary file
    [Arguments]         ${duration}    ${operation_count}    ${avg_time}
    ${footer}=          Set Variable    \nTotal Duration: ${duration}s\nTotal Operations: ${operation_count}\nAverage Time per Operation: ${avg_time}s
    Append To File      ${SUMMARY_FILE}    ${footer}

Simulate Concurrent Adjustments
    [Documentation]     Simulate concurrent adjustments to an inventory record
    [Arguments]         ${inventory_id}    ${adjustment_template}    ${thread_count}=${CONCURRENT_THREADS}
    ${processes}=       Create List
    FOR    ${index}    IN RANGE    ${thread_count}
    \    ${adjustment_data}=    Copy Dictionary    ${adjustment_template}
    \    Set To Dictionary  ${adjustment_data}    note=Adjustment by Thread ${index}
    \    ${process}=        Start Process    robot    -c    Adjust Inventory    ${adjustment_data}    shell=True
    \    Append To List    ${processes}    ${process}
    END
    FOR    ${process}    IN    @{processes}
    \    ${result}=        Wait For Process    ${process}
    \    Should Be Equal As Integers    ${result.rc}    0    msg=Concurrent adjustment process failed
    END
    ${final_inventory}= Get Inventory By ID    ${inventory_id}
    RETURN            ${final_inventory}

*** Test Cases ***
01 - Create Inventory Record Test
    [Documentation]     Test creating a new inventory record
    [Tags]              create    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${inventory_data}=  Generate Inventory Data    ${TEST_WAREHOUSE_ID}    ${TEST_PRODUCT_ID}
    ${inventory_id}    ${response}=    Create Inventory    ${inventory_data}
    Should Not Be Empty    ${inventory_id}
    Assert Inventory Details    ${response}    ${inventory_data}
    Set Global Variable  ${TEST_INVENTORY_ID}    ${inventory_id}
    Log Response Details  ${response}    Inventory Creation
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully created inventory record: ${inventory_id}

02 - Create Inventory Invalid Product Test
    [Documentation]     Test creating inventory with invalid product ID
    [Tags]              create    negative    dependency
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Inventory Data    ${TEST_WAREHOUSE_ID}    99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Inventory Creation (Invalid Product)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified inventory creation fails with invalid product

03 - Adjust Inventory Increase Stock Test
    [Documentation]     Test increasing stock in an inventory record
    [Tags]              adjust    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${adjustment_data}= Generate Adjustment Data    ${TEST_INVENTORY_ID}    50
    ${adjustment_id}    ${response}=    Adjust Inventory    ${adjustment_data}
    Should Not Be Empty    ${adjustment_id}
    Set Global Variable  ${TEST_ADJUSTMENT_ID}    ${adjustment_id}
    ${inventory}=       Get Inventory By ID    ${TEST_INVENTORY_ID}
    Should Be Equal As Integers    ${inventory}[currentQuantity]    150
    Log Response Details  ${response}    Inventory Adjustment (Increase)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully increased stock by 50: ${inventory}[currentQuantity]

04 - Adjust Inventory Decrease Stock Test
    [Documentation]     Test decreasing stock in an inventory record
    [Tags]              adjust    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${adjustment_data}= Generate Adjustment Data    ${TEST_INVENTORY_ID}    -30    reason=STOCK_LOSS
    ${adjustment_id}    ${response}=    Adjust Inventory    ${adjustment_data}
    Should Not Be Empty    ${adjustment_id}
    ${inventory}=       Get Inventory By ID    ${TEST_INVENTORY_ID}
    Should Be Equal As Integers    ${inventory}[currentQuantity]    120
    Log Response Details  ${response}    Inventory Adjustment (Decrease)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully decreased stock by 30: ${inventory}[currentQuantity]

05 - Adjust Inventory Negative Stock Test
    [Documentation]     Test adjusting stock to below zero
    [Tags]              adjust    negative    edge
    ${start_time}=      Get Current Date    result_format=epoch
    ${adjustment_data}= Generate Adjustment Data    ${TEST_INVENTORY_ID}    -200
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/adjust
    ...                 json=${adjustment_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    ${inventory}=       Get Inventory By ID    ${TEST_INVENTORY_ID}
    Should Be Equal As Integers    ${inventory}[currentQuantity]    120    # Should not change
    Log Response Details  ${response}    Inventory Adjustment (Negative Stock)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified adjustment fails for negative stock

06 - Retrieve Inventory Test
    [Documentation]     Test retrieving an inventory record
    [Tags]              retrieve    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${inventory}=       Get Inventory By ID    ${TEST_INVENTORY_ID}
    Should Be Equal As Integers    ${inventory}[currentQuantity]    120
    Log Response Details  ${inventory}    Inventory Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved inventory: ${inventory}[id]

07 - Retrieve Adjustment History Test
    [Documentation]     Test retrieving adjustment history
    [Tags]              retrieve    positive    audit
    ${start_time}=      Get Current Date    result_format=epoch
    ${history}=         Get Adjustment History    ${TEST_INVENTORY_ID}
    ${json}=            Evaluate    json.loads('''${history.text}''')    json
    Should Be True      ${json.__len__()} >= 2    msg=Expected at least 2 adjustments in history
    Log Response Details  ${history}    Adjustment History Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved adjustment history with ${json.__len__()} entries

08 - Concurrent Inventory Adjustments Test
    [Documentation]     Test concurrent stock adjustments
    [Tags]              adjust    positive    concurrency
    ${start_time}=      Get Current Date    result_format=epoch
    ${adjustment_template}= Generate Adjustment Data    ${TEST_INVENTORY_ID}    10
    ${final_inventory}= Simulate Concurrent Adjustments    ${TEST_INVENTORY_ID}    ${adjustment_template}
    Should Be Equal As Integers    ${final_inventory}[currentQuantity]    150    # 120 + (3 * 10)
    Log Response Details  ${final_inventory}    Inventory After Concurrent Adjustments
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully performed concurrent adjustments: ${final_inventory}[currentQuantity]

09 - Adjust Inventory Invalid ID Test
    [Documentation]     Test adjusting inventory with invalid ID
    [Tags]              adjust    negative
    ${start_time}=      Get Current Date    result_format=epoch
    ${adjustment_data}= Generate Adjustment Data    99999999    50
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /inventory/adjust
    ...                 json=${adjustment_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Inventory Adjustment (Invalid ID)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified adjustment fails with invalid inventory ID

10 - Full Inventory Audit Flow Test
    [Documentation]     Test a complete inventory audit flow
    [Tags]              create    adjust    retrieve    positive    workflow
    ${start_time}=      Get Current Date    result_format=epoch
    # Create new inventory
    ${inventory_data}=  Generate Inventory Data    ${TEST_WAREHOUSE_ID}    ${TEST_PRODUCT_ID}
    ${inventory_id}    ${i_response}=    Create Inventory    ${inventory_data}
    Log Response Details  ${i_response}    Full Flow Inventory Creation
    # Adjust stock multiple times
    ${adjust1_data}=    Generate Adjustment Data    ${inventory_id}    20    reason=RECEIVED
    ${adjust1_id}    ${a1_response}=    Adjust Inventory    ${adjust1_data}
    Log Response Details  ${a1_response}    Full Flow Adjustment 1
    ${adjust2_data}=    Generate Adjustment Data    ${inventory_id}    -10    reason=SHIPPED
    ${adjust2_id}    ${a2_response}=    Adjust Inventory    ${adjust2_data}
    Log Response Details  ${a2_response}    Full Flow Adjustment 2
    # Verify final state
    ${inventory}=       Get Inventory By ID    ${inventory_id}
    Should Be Equal As Integers    ${inventory}[currentQuantity]    110    # 100 + 20 - 10
    Log Response Details  ${inventory}    Full Flow Inventory Retrieval
    # Check audit trail
    ${history}=         Get Adjustment History    ${inventory_id}
    ${json}=            Evaluate    json.loads('''${history.text}''')    json
    Should Be Equal As Integers    ${json.__len__()}    2
    # Cleanup
    Delete Inventory    ${inventory_id}
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully completed full inventory audit flow: ${inventory_id}