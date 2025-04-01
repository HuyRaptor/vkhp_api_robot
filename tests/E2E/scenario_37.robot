*** Settings ***
Documentation     End-to-End Test Suite for vKho Purchase Order Management
...               Covers purchase order creation, lifecycle management, and validation
...               Includes positive, negative, edge, concurrency, and workflow tests
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           String
Library           DateTime
Library           Process
Suite Setup       Setup Test Suite
Suite Teardown    Teardown Test Suite

*** Variables ***
${BASE_URL}             https://api.vkho.net
${USERNAME}             huynh22.manager
${PASSWORD}             Snowfox1991
${RESULTS_DIR}          ${CURDIR}${/}results
${SUMMARY_FILE}         ${RESULTS_DIR}${/}purchase_order_test_summary.txt
${TEST_WAREHOUSE_ID}    ${EMPTY}
${TEST_SUPPLIER_ID}     ${EMPTY}
${TEST_PURCHASE_ORDER_ID}  ${EMPTY}
${TEST_WAREHOUSE_NAME}  ${EMPTY}
${TEST_SUPPLIER_NAME}   ${EMPTY}
${TEST_PURCHASE_ORDER_CODE}  ${EMPTY}
${MAX_RETRIES}          3
${RETRY_DELAY}          2
${START_TIME}           ${EMPTY}
${OPERATION_COUNT}      0
${TIMEOUT_DELAY}        5    # Simulated timeout delay in seconds
${API_VERSION}          v1.1
${PAGE_SIZE}            10
${CONCURRENT_THREADS}   3    # Number of concurrent operations

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
    ${supplier_data}=   Generate Unique Supplier Data    ${warehouse_id}
    ${supplier_id}    ${s_response}=    Create Supplier    ${supplier_data}
    Set Global Variable  ${TEST_SUPPLIER_ID}     ${supplier_id}
    Set Global Variable  ${TEST_SUPPLIER_NAME}   ${supplier_data}[name]

Teardown Test Suite
    [Documentation]     Clean up all created resources and log suite metrics
    Run Keyword If      "${TEST_PURCHASE_ORDER_ID}" != "${EMPTY}"    Delete Purchase Order    ${TEST_PURCHASE_ORDER_ID}
    Run Keyword If      "${TEST_SUPPLIER_ID}" != "${EMPTY}"    Delete Supplier    ${TEST_SUPPLIER_ID}
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
    ${warehouse_name}=  Set Variable     PO Warehouse ${timestamp}
    ${warehouse_data}=  Create Dictionary
    ...                 name=${warehouse_name}
    ...                 address=789 PO Street
    ...                 acreage=1500
    [Return]            ${warehouse_data}

Generate Unique Supplier Data
    [Documentation]     Generate unique data for supplier tests
    [Arguments]         ${warehouse_id}
    ${timestamp}=       Evaluate         int(time.time())    time
    ${supplier_name}=   Set Variable     PO Supplier ${timestamp}
    ${supplier_data}=   Create Dictionary
    ...                 name=${supplier_name}
    ...                 email=po_supplier_${timestamp}@example.com
    ...                 phoneNumber=900123${timestamp}
    ...                 address=PO Supplier Address
    ...                 isActive=${TRUE}
    ...                 contractNumber=PO${timestamp}
    ...                 taxCode=12345${timestamp}
    ...                 cooperationDay=2023-04-01T00:00:00.000Z
    ...                 warehouseId=${warehouse_id}
    [Return]            ${supplier_data}

Generate Purchase Order Data
    [Documentation]     Generate data for purchase order creation
    [Arguments]         ${warehouse_id}    ${supplier_id}    ${total_quantity}=50
    ${timestamp}=       Evaluate         int(time.time())    time
    ${po_code}=         Set Variable     PO${timestamp}
    ${items}=           Create List
    ${item}=            Create Dictionary
    ...                 productName=PO Product ${timestamp}
    ...                 quantity=${total_quantity}
    ...                 unitPrice=10
    ...                 totalPrice=${total_quantity * 10}
    Append To List      ${items}    ${item}
    ${po_data}=         Create Dictionary
    ...                 code=${po_code}
    ...                 warehouseId=${warehouse_id}
    ...                 supplierId=${supplier_id}
    ...                 status=DRAFT
    ...                 orderDate=2025-04-01T00:00:00.000Z
    ...                 expectedDeliveryDate=2025-04-10T00:00:00.000Z
    ...                 items=${items}
    ...                 totalAmount=${total_quantity * 10}
    ...                 note=Test PO ${timestamp}
    [Return]            ${po_data}

Create Warehouse With Retry
    [Documentation]     Create a new warehouse with retry logic
    [Arguments]         ${warehouse_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${attempt}=         Set Variable    1
    :FOR    ${attempt}    IN RANGE    1    ${MAX_RETRIES + 1}
    \    ${response}=    Run Keyword And Ignore Error
    \    ...             POST On Session    vkho    /warehouses/create    json=${warehouse_data}    headers=${headers}    expected_status=anything
    \    ${status}=      Set Variable If    "${response[0]}" == "PASS"    ${response[1].status_code}    500
    \    Exit For Loop If    ${status} == 201
    \    Sleep           ${RETRY_DELAY}
    \    Run Keyword If  ${attempt} == ${MAX_RETRIES}    Fail    Failed to create warehouse after ${MAX_RETRIES} attempts
    ${json}=            Evaluate         json.loads('''${response[1].text}''')    json
    ${warehouse_id}=    Convert To String    ${json}[id]
    Increment Operation Count
    [Return]            ${warehouse_id}    ${response[1]}

Create Supplier
    [Documentation]     Create a new supplier and return its ID
    [Arguments]         ${supplier_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /suppliers/create
    ...                 json=${supplier_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${supplier_id}=     Convert To String    ${json}[id]
    Increment Operation Count
    [Return]            ${supplier_id}    ${response}

Create Purchase Order
    [Documentation]     Create a new purchase order
    [Arguments]         ${po_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${po_data}
    ...                 headers=${headers}
    ...                 expected_status=201
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    ${po_id}=           Convert To String    ${json}[id]
    Increment Operation Count
    [Return]            ${po_id}    ${response}

Update Purchase Order
    [Documentation]     Update an existing purchase order
    [Arguments]         ${po_id}    ${update_data}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /purchase-orders/update
    ...                 json=${update_data}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    [Return]            ${response}

Get Purchase Order By ID
    [Documentation]     Retrieve a purchase order by ID
    [Arguments]         ${po_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /purchase-orders/get-one/${po_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    [Return]            ${response}

Get Purchase Orders Paginated
    [Documentation]     Retrieve purchase orders with pagination
    [Arguments]         ${page}=1    ${size}=${PAGE_SIZE}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${params}=          Create Dictionary    page=${page}    size=${size}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /purchase-orders
    ...                 params=${params}
    ...                 headers=${headers}
    ...                 expected_status=200
    ${json}=            Evaluate         json.loads('''${response.text}''')    json
    Increment Operation Count
    [Return]            ${response}

Delete Purchase Order
    [Documentation]     Delete a purchase order from the system
    [Arguments]         ${po_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /purchase-orders/delete/${po_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    [Return]            ${TRUE}

Delete Supplier
    [Documentation]     Delete a supplier from the system
    [Arguments]         ${supplier_id}
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        DELETE On Session
    ...                 vkho
    ...                 /suppliers/delete/${supplier_id}
    ...                 headers=${headers}
    ...                 expected_status=200
    Increment Operation Count
    [Return]            ${TRUE}

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
    [Return]            ${TRUE}

Assert PO Details
    [Documentation]     Verify purchase order details match expected values
    [Arguments]         ${po}    ${expected_data}
    FOR    ${key}    IN    @{expected_data.keys()}
        Run Keyword If    "${key}" in ${po}    Should Be Equal    ${po}[${key}]    ${expected_data}[${key}]
        ...    msg=PO ${key} value '${po}[${key}]' does not match expected '${expected_data}[${key}]'
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
    ${header}=          Set Variable    Purchase Order Test Summary Report\n==================\nTest Name\tDuration (s)\n
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

Simulate Concurrent Updates
    [Documentation]     Simulate concurrent updates to a purchase order
    [Arguments]         ${po_id}    ${update_template}    ${thread_count}=${CONCURRENT_THREADS}
    ${processes}=       Create List
    :FOR    ${index}    IN RANGE    ${thread_count}
    \    ${update_data}=    Copy Dictionary    ${update_template}
    \    Set To Dictionary  ${update_data}    note=Updated by Thread ${index}
    \    ${process}=        Start Process    robot    -c    Update Purchase Order    ${po_id}    ${update_data}    shell=True
    \    Append To List    ${processes}    ${process}
    :FOR    ${process}    IN    @{processes}
    \    ${result}=        Wait For Process    ${process}
    \    Should Be Equal As Integers    ${result.rc}    0    msg=Concurrent update process failed
    ${final_po}=        Get Purchase Order By ID    ${po_id}
    [Return]            ${final_po}

*** Test Cases ***
01 - Create Purchase Order Test
    [Documentation]     Test creating a new purchase order
    [Tags]              create    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${po_data}=         Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${po_id}    ${response}=    Create Purchase Order    ${po_data}
    Should Not Be Empty    ${po_id}
    Assert PO Details   ${response}    ${po_data}
    Set Global Variable  ${TEST_PURCHASE_ORDER_ID}    ${po_id}
    Set Global Variable  ${TEST_PURCHASE_ORDER_CODE}  ${po_data}[code]
    Log Response Details  ${response}    Purchase Order Creation
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully created purchase order: ${TEST_PURCHASE_ORDER_CODE}

02 - Create Purchase Order Invalid Supplier Test
    [Documentation]     Test creating a purchase order with invalid supplier ID
    [Tags]              create    negative    dependency
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    99999999
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Purchase Order Creation (Invalid Supplier)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified PO creation fails with invalid supplier

03 - Update Purchase Order to Approved Test
    [Documentation]     Test updating purchase order status to APPROVED
    [Tags]              update    positive    status
    ${start_time}=      Get Current Date    result_format=epoch
    ${update_data}=     Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    Set To Dictionary   ${update_data}    id=${TEST_PURCHASE_ORDER_ID}    status=APPROVED
    ${response}=        Update Purchase Order    ${TEST_PURCHASE_ORDER_ID}    ${update_data}
    Should Be Equal     ${response}[status]    APPROVED
    Log Response Details  ${response}    Purchase Order Update (Approved)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully updated PO to APPROVED: ${TEST_PURCHASE_ORDER_CODE}

04 - Update Purchase Order to Fulfilled Test
    [Documentation]     Test updating purchase order status to FULFILLED
    [Tags]              update    positive    status
    ${start_time}=      Get Current Date    result_format=epoch
    ${update_data}=     Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    Set To Dictionary   ${update_data}    id=${TEST_PURCHASE_ORDER_ID}    status=FULFILLED
    ${response}=        Update Purchase Order    ${TEST_PURCHASE_ORDER_ID}    ${update_data}
    Should Be Equal     ${response}[status]    FULFILLED
    Log Response Details  ${response}    Purchase Order Update (Fulfilled)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully updated PO to FULFILLED: ${TEST_PURCHASE_ORDER_CODE}

05 - Retrieve Purchase Order Test
    [Documentation]     Test retrieving a purchase order
    [Tags]              retrieve    positive
    ${start_time}=      Get Current Date    result_format=epoch
    ${po}=              Get Purchase Order By ID    ${TEST_PURCHASE_ORDER_ID}
    Should Be Equal     ${po}[code]    ${TEST_PURCHASE_ORDER_CODE}
    Should Be Equal     ${po}[status]    FULFILLED
    Log Response Details  ${po}    Purchase Order Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved PO: ${TEST_PURCHASE_ORDER_CODE}

06 - Retrieve Paginated Purchase Orders Test
    [Documentation]     Test retrieving purchase orders with pagination
    [Tags]              retrieve    positive    pagination
    ${start_time}=      Get Current Date    result_format=epoch
    ${response}=        Get Purchase Orders Paginated    page=1    size=${PAGE_SIZE}
    ${json}=            Evaluate    json.loads('''${response.text}''')    json
    Should Be True      ${json.__len__()} <= ${PAGE_SIZE}
    Log Response Details  ${response}    Purchase Orders Paginated Retrieval
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully retrieved paginated POs (up to ${PAGE_SIZE} items)

07 - Create Purchase Order Negative Quantity Test
    [Documentation]     Test creating a purchase order with negative quantity
    [Tags]              create    negative    edge
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}    total_quantity=-10
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        POST On Session
    ...                 vkho
    ...                 /purchase-orders/create
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    201
    Log Response Details  ${response}    Purchase Order Creation (Negative Quantity)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified PO creation fails with negative quantity

08 - Concurrent Purchase Order Updates Test
    [Documentation]     Test concurrent updates to a purchase order
    [Tags]              update    positive    concurrency
    ${start_time}=      Get Current Date    result_format=epoch
    ${update_template}= Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    Set To Dictionary   ${update_template}    id=${TEST_PURCHASE_ORDER_ID}    status=APPROVED
    ${final_po}=        Simulate Concurrent Updates    ${TEST_PURCHASE_ORDER_ID}    ${update_template}
    Should Be Equal     ${final_po}[status]    APPROVED
    Log Response Details  ${final_po}    Purchase Order After Concurrent Updates
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully performed concurrent updates: ${final_po}[code]

09 - Update Purchase Order Invalid Status Test
    [Documentation]     Test updating purchase order with invalid status
    [Tags]              update    negative    validation
    ${start_time}=      Get Current Date    result_format=epoch
    ${invalid_data}=    Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    Set To Dictionary   ${invalid_data}    id=${TEST_PURCHASE_ORDER_ID}    status=INVALID_STATUS
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        PUT On Session
    ...                 vkho
    ...                 /purchase-orders/update
    ...                 json=${invalid_data}
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    200
    Log Response Details  ${response}    Purchase Order Update (Invalid Status)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified PO update fails with invalid status

10 - Full Purchase Order Lifecycle Test
    [Documentation]     Test a complete purchase order lifecycle
    [Tags]              create    update    retrieve    positive    workflow
    ${start_time}=      Get Current Date    result_format=epoch
    # Create PO
    ${po_data}=         Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${po_id}    ${c_response}=    Create Purchase Order    ${po_data}
    Log Response Details  ${c_response}    Full Flow PO Creation
    # Update to APPROVED
    ${update1_data}=    Copy Dictionary    ${po_data}
    Set To Dictionary   ${update1_data}    id=${po_id}    status=APPROVED
    ${u1_response}=     Update Purchase Order    ${po_id}    ${update1_data}
    Log Response Details  ${u1_response}    Full Flow PO Update (Approved)
    # Update to FULFILLED
    ${update2_data}=    Copy Dictionary    ${po_data}
    Set To Dictionary   ${update2_data}    id=${po_id}    status=FULFILLED
    ${u2_response}=     Update Purchase Order    ${po_id}    ${update2_data}
    Log Response Details  ${u2_response}    Full Flow PO Update (Fulfilled)
    # Verify final state
    ${po}=              Get Purchase Order By ID    ${po_id}
    Should Be Equal     ${po}[status]    FULFILLED
    Log Response Details  ${po}    Full Flow PO Retrieval
    # Cleanup
    Delete Purchase Order    ${po_id}
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully completed full PO lifecycle: ${po_id}

11 - Delete Purchase Order Test
    [Documentation]     Test deleting a purchase order
    [Tags]              delete    positive
    ${start_time}=      Get Current Date    result_format=epoch
    # Create a temporary PO for deletion
    ${po_data}=         Generate Purchase Order Data    ${TEST_WAREHOUSE_ID}    ${TEST_SUPPLIER_ID}
    ${po_id}    ${response}=    Create Purchase Order    ${po_data}
    ${result}=          Delete Purchase Order    ${po_id}
    Should Be True      ${result}
    Log Response Details  ${response}    Purchase Order Creation (For Deletion)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully deleted PO: ${po_id}

12 - Retrieve Non-Existent Purchase Order Test
    [Documentation]     Test retrieving a non-existent purchase order
    [Tags]              retrieve    negative
    ${start_time}=      Get Current Date    result_format=epoch
    ${headers}=         Create Dictionary    Content-Type=application/json    Authorization=${AUTH_TOKEN}
    ${response}=        GET On Session
    ...                 vkho
    ...                 /purchase-orders/get-one/99999999
    ...                 headers=${headers}
    ...                 expected_status=anything
    Should Not Equal    ${response.status_code}    200
    Log Response Details  ${response}    Purchase Order Retrieval (Non-Existent)
    ${end_time}=        Get Current Date    result_format=epoch
    ${test_duration}=   Evaluate    ${end_time} - ${start_time}
    Append To Summary   ${TEST NAME}    ${test_duration}
    Log                 Successfully verified retrieval fails for non-existent PO