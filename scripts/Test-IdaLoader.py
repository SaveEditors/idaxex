import ida_ida
import ida_loader
import ida_nalt
import ida_pro

print("[idaxex-smoke] input=%s" % ida_nalt.get_input_file_path())
print("[idaxex-smoke] filetype=%s" % ida_loader.get_file_type_name())
print("[idaxex-smoke] processor=%s" % ida_ida.inf_get_procname())

ida_pro.qexit(0)
