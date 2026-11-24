import os
import json
import shutil

from robot.api import logger
import robot.utils.asserts
from robot.libraries.BuiltIn import BuiltIn


class AutomationFlow(object):
    __version__ = 'V1.2.0'
    __date__ = '2024/12/20'
    __author__ = "Jet Qian"
    ROBOT_LIBRARY_SCOPE = 'TEST'

    def __init__(self):
        self.result_folder =  ""
        self.tmp_result_path = "" 

    @property
    def _result_root_path(self):
        return BuiltIn().get_variable_value("${RESULT_ROOT_PATH}")

    @property
    def _suite_name(self):
        suite_full_name = BuiltIn().get_variable_value("${SUITE NAME}")
        suite_name = suite_full_name.rsplit('#')[-1]
        return suite_name
    
    def _get_robot_running_var(self):
        self.result_folder = os.path.join(self._result_root_path, self._suite_name)
        self.tmp_result_path = os.path.join(self.result_folder, "_tmp_result.json")

    # Check and Warn if pre-defined variables are not declared in robot framework by user
    def _check_robot_variable(self):
        #${RESULT_ROOT_PATH}
        rslt = BuiltIn().get_variable_value("${RESULT_ROOT_PATH}")
        if rslt == None:
            robot.utils.asserts.fail("ERROR<>Can NOT find \"$RESULT_ROOT_PATH\" in robot") 
        # Do NOT need to check ${SUITE NAME}, it is built-in variables in Robot Framework

    def get_tmp_result(self, test_id, name="_tmp_result.json"):
        # Need to Review again 2023/12/07
        """Get json result from external script

        !! Need to Review again 2023/12/07 !!

        Result path will follow Global Environment Variable which is
        ${RESULT_ROOT_PATH}${/}${case_name}/

        Default result name is "_tmp_result.json", it also supports user defined name

        However, no matter what name result.json is, it must be followed specific format

        *Format of _tmp_result.json:*
        | {
        |    "case_id": {
        |        "result": "PASS",
        |         "msg": "PASS<>pass reason"
        |    },
        |     "1.2.3.4.5": {
        |         "result": "FAIL",
        |         "msg": "FAIL<>fail reason"
        |    }
        | }


        *Examples:*
        | Get Tmp Result | case_id | #Default json name |
        | Get Tmp Result | 1.2.3.4.5 | user_defined_file_name |
        """
        arg_info = "{}, name={}".format(test_id, name)
        logger.write("[Arguments]: {}".format(arg_info), 'INFO')
        logger.console("\n\tAutomationFlow - Get Tmp Result : {}".format(arg_info))
        self._check_robot_variable()
        self._get_robot_running_var()
        if name != "_tmp_result.json":
            tmp_path = os.path.join(self.result_folder, name)
        else:
            tmp_path = self.tmp_result_path

        self._is_tmp_result_exist(tmp_path)
        json_obj = self._load_json(tmp_path)
        self._is_test_id_exist(json_obj, test_id)
        self._result_judgement(json_obj[test_id])

    def automation_initial(self):
        """Initialize automation setting before running each test suite

        1) It will create result folder ${RESULT_ROOT_PATH}${/}${case_name}/

        2) If result folder exists already, do nothing

        *Examples:*
        | Automation Initial |
        """        
        logger.console("\n\tAutomationFlow - Automation Initial")
        self._check_robot_variable()
        self._get_robot_running_var()
        if not os.path.exists(self.result_folder):
            os.makedirs(self.result_folder)
        # If folder exist, do nothing
        # else:
        #     shutil.rmtree(self.result_folder)
        #     os.makedirs(self.result_folder)
    

    def _is_tmp_result_exist(self, path):
        if os.path.exists(path):
            return 1
        else:
            robot.utils.asserts.fail("FAIL<>Tmp File \"{}\" does NOT exist".format(path))

    def _load_json(self, path):
        try:
            with open(path) as json_file:
                data = json.load(json_file)
            return data
        except Exception as e:
            robot.utils.asserts.fail("ERROR<>Fail to read \"{}\" : {}".format(path, e))

    def _is_test_id_exist(self, json_data, test_id):
        if test_id not in json_data.keys():
            robot.utils.asserts.fail("ERROR<>Test_id \"{}\" is not in tmp json file".format(test_id))
        for x in ["result", "msg"]:
            if x not in json_data[test_id].keys():
                robot.utils.asserts.fail("ERROR<>Can not find \"{}\" jobmeter in \"{}\" section in tmp json file"
                                         .format(x, test_id))

    def _result_judgement(self, test: dict):
        if test["result"] == "PASS":
            logger.write(test["msg"], 'INFO')
        else:
            robot.utils.asserts.fail(test["msg"])


def _library_info(job):
    obj = AutomationFlow
    md_info = obj.__dict__
    if job == '-v':
        print(md_info["__version__"])
    elif job == '-l':
        print("{:30s}: {:6s} | {:8s} | {:10s}"
              .format(obj.__name__, md_info["__version__"], md_info["__date__"], md_info["__author__"]))
    elif job == '-h':
        print("Library Name : {}".format(obj.__name__))
        print("Library Version : {}".format(md_info["__version__"]))
        print("Library Author : {}".format(md_info["__author__"]))
        method_list = [method for method in md_info.keys() if callable(md_info[method])]
        method_list = [method for method in method_list if (method.startswith('__') or method.startswith('_')) is False]
        print("Available Custom Keywords : ")
        for x in method_list:
            print("\t{}.{}".format(obj.__name__, x))

        property_list = [pro for pro in md_info.keys() if isinstance(md_info[pro], property)]
        if property_list:
            print("Property value from using Robot Framework \"get_variable_value\" function :")
            for x in property_list:
                print("\t{}".format(x))
        else:
            pass


if __name__ == '__main__':
    import sys
    # Show version only when get -v 
    # Show version / date / author when get -l
    # Other situation show full library info
    if len(sys.argv) == 2:
        if sys.argv[1].lower() == "-v":
            _library_info("-v")
        elif sys.argv[1].lower() == "-l":
            _library_info("-l")
        else:
            _library_info("-h")