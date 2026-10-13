"""Bounded guard cleanup policy, with injected native and filesystem effects."""
import time


def finish_owned_run(*, receipt, terminate, inventory, close_job, child, paths,
                     unlink, deadline, process_deadline, started, utc,
                     write_receipt, clock=time.monotonic, sleep=time.sleep):
    errors = []
    remaining = None
    termination_ok = False
    try:
        try:
            termination_ok = bool(terminate())
            if not termination_ok:
                errors.append('TerminateJobObject returned failure')
        except Exception as exc:
            errors.append('termination: ' + str(exc))
        if child:
            try:
                child.wait(timeout=max(0, process_deadline - clock()))
            except Exception as exc:
                errors.append('root exit: ' + str(exc))
        try:
            # Bound both time and iterations, including unusual clock behavior.
            for _ in range(121):
                remaining = inventory()
                if not remaining or clock() >= process_deadline:
                    break
                sleep(min(0.05, max(0, process_deadline - clock())))
            if remaining:
                errors.append('owned descendants still present at cleanup deadline')
        except Exception as exc:
            errors.append('exit inventory: ' + str(exc))
        finally:
            try:
                if not close_job():
                    errors.append('CloseHandle returned failure')
            except Exception as exc:
                errors.append('job close: ' + str(exc))
        deferred = []
        for index, path in enumerate(paths):
            if clock() >= deadline:
                deferred.extend(str(value) for value in paths[index:])
                errors.append('generated-file cleanup deadline reached')
                break
            try:
                unlink(path)
            except Exception as exc:
                deferred.append(str(path))
                errors.append('generated-file cleanup: ' + str(exc))
        receipt.update(termination_succeeded=termination_ok,
                       remaining_owned_pids=remaining,
                       process_cleanup_confirmed=remaining == [],
                       deferred_generated_files=deferred)
    except Exception as exc:
        errors.append('cleanup exception: ' + str(exc))
    finally:
        receipt.update(ended_utc=utc(), elapsed_including_cleanup=clock() - started,
                       cleanup_error='; '.join(errors) if errors else None)
        if clock() >= deadline:
            receipt['cleanup_deadline_reached'] = True
        # A failed unlink/termination/exit wait must never suppress the receipt.
        write_receipt(receipt)
    return receipt
